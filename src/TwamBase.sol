// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {SafeCastLib} from "@solmate/utils/SafeCastLib.sol";
import {Clone} from "@clones/Clone.sol";

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC721} from "./interfaces/IERC721.sol";

////////////////////////////////////////////////////
///                 CUSTOM ERRORS                ///
////////////////////////////////////////////////////

/// Invalid Session
/// @param sessionId The session's id
error InvalidSession(uint256 sessionId);

/// Not during the Allocation Period
/// @param blockNumber block.number
/// @param allocationStart The block number that marks when the allocation starts
/// @param allocationEnd The block number that marks when the allocation ends
error NonAllocation(uint256 blockNumber, uint64 allocationStart, uint64 allocationEnd);

/// Not during the Minting Period
/// @param blockNumber block.number
/// @param mintingStart The block number that marks when the minting period starts
/// @param mintingEnd The block number that marks when the minting period ends
error NonMinting(uint256 blockNumber, uint64 mintingStart, uint64 mintingEnd);

/// Make sure the sender has enough deposits
/// @param sender The message sender
/// @param deposits The user's deposits in the session
/// @param amount The amount a user want's to mint with
error InsufficientDesposits(address sender, uint256 deposits, uint256 amount);

/// The Minting Period is not Over
/// @param blockNumber The current block.number
/// @param mintingEnd When the session minting period ends
error MintingNotOver(uint256 blockNumber, uint64 mintingEnd);

/// Invalid Coordinator
/// @param sender The msg sender
/// @param coordinator The expected session coordinator
error InvalidCoordinator(address sender, address coordinator);

////////////////////////////////////////////////////
///                     TWAM                     ///
////////////////////////////////////////////////////

/// @title TwamBase
/// @notice Time Weighted Asset Mints
/// @author Andreas Bigger <andreas@nascent.xyz>
contract TwamBase is Clone {

  /// @notice Maps a user to their deposits
  mapping(address => uint256) public deposits;

  /// @notice Session Rewards for Coordinators
  uint256 public rewards;

  ////////////////////////////////////////////////////
  ///           SESSION MANAGEMENT LOGIC           ///
  ////////////////////////////////////////////////////

  /// @notice Allows the coordinator to rollover 
  /// @notice Requires the minting period to be over
  function rollover(uint256 sessionId) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == address(0)) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    if (msg.sender != sess.coordinator) {
      revert InvalidCoordinator(msg.sender, sess.coordinator);
    }

    // Require Minting to be complete
    if (block.number < sess.mintingEnd) {
      revert MintingNotOver(block.number, sess.mintingEnd);
    }

    // Rollover Options
    // 1. Restart the twam
    // 2. Mint at resulting price or minimum if not reached
    // 3. Close Session
    if(sess.rolloverOption == 2) {
      // We can just make the mintingEnd the maximum number
      sess.mintingEnd = type(uint64).max;
    }
    if(sess.rolloverOption == 1) {
      uint64 allocationPeriod = sess.allocationEnd - sess.allocationStart;
      uint64 cooldownPeriod = sess.mintingStart - sess.allocationEnd;
      uint64 mintingPeriod = sess.mintingEnd - sess.mintingStart;

      // Reset allocation period
      sess.allocationStart = SafeCastLib.safeCastTo64(block.number);
      sess.allocationEnd = allocationPeriod + SafeCastLib.safeCastTo64(block.number);

      // Reset Minting period
      sess.mintingStart = SafeCastLib.safeCastTo64(block.number) + allocationPeriod + cooldownPeriod;
      sess.mintingEnd = sess.mintingStart + mintingPeriod;
    }

    // Otherwise, do nothing.
    // If the session is closed, we just allow the users to withdraw
  }

  /// @notice Allows the coordinator to withdraw session rewards
  /// @param baseToken The token to transfer to the coordinator
  function withdrawRewards(address baseToken) public {
    uint256 rewardAmount = rewards[msg.sender][baseToken];
    rewards[msg.sender][baseToken] = 0; 
    IERC20(baseToken).transfer(msg.sender, rewardAmount);
  }

  ////////////////////////////////////////////////////
  ///           SESSION ALLOCATION PERIOD          ///
  ////////////////////////////////////////////////////

  /// @notice Deposit a deposit token into a session
  /// @dev requires approval of the deposit token
  /// @param sessionId The session id
  /// @param amount The amount of the deposit token to deposit
  function deposit(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == address(0)) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the allocation period
    if (block.number > sess.allocationEnd || block.number < sess.allocationStart) {
      revert NonAllocation(block.number, sess.allocationStart, sess.allocationEnd);
    }

    // Transfer the token to this contract
    IERC20(sess.depositToken).transferFrom(msg.sender, address(this), amount);

    // Update the user's deposit amount and total session deposits
    deposits[msg.sender][sessionId] += amount;
    sess.depositAmount += amount;
  }

  /// @notice Withdraws a deposit token from a session
  /// @param sessionId The session id
  /// @param amount The amount of the deposit token to withdraw
  function withdraw(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == address(0)) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the allocation period
    if (
      (block.number > sess.allocationEnd || block.number < sess.allocationStart)
      &&
      (block.number < sess.mintingEnd || sess.rolloverOption != 3) // Allows a user to withdraw deposits if session ends
      ) {
      revert NonAllocation(block.number, sess.allocationStart, sess.allocationEnd);
    }

    // Update the user's deposit amount and total session deposits
    // This will revert on underflow so no need to check amount
    deposits[msg.sender][sessionId] -= amount;
    sess.depositAmount -= amount;

    // Transfer the token to this contract
    IERC20(sess.depositToken).transfer(msg.sender, amount);
  }

  ////////////////////////////////////////////////////
  ///            SESSION MINTING PERIOD            ///
  ////////////////////////////////////////////////////

  /// @notice Mints tokens during minting period
  /// @param sessionId The session Id
  /// @param amount The amount of deposits to mint with
  function mint(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == address(0)) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the minting period
    if (block.number > sess.mintingEnd || block.number < sess.mintingStart) {
      revert NonMinting(block.number, sess.mintingStart, sess.mintingEnd);
    }

    // Calculate the mint price
    if(sess.resultPrice == 0) {
      sess.resultPrice = sess.depositAmount / sess.maxMintingAmount;
    }
    uint256 mintPrice = sess.resultPrice > sess.minPrice ? sess.resultPrice : sess.minPrice;

    // Make sure the user has enough deposits and can mint
    if (deposits[msg.sender][sessionId] < amount || amount < mintPrice) {
      revert InsufficientDesposits(msg.sender, deposits[msg.sender][sessionId], amount);
    }

    // Calculate mint amount and transfer
    uint256 numberToMint = amount / mintPrice;
    sess.maxMintingAmount -= numberToMint;
    deposits[msg.sender][sessionId] -= numberToMint * mintPrice;
    sess.depositAmount -= numberToMint * mintPrice;
    for(uint256 i = 0; i < numberToMint; i++) {
      IERC721(sess.token).safeTransferFrom(address(this), msg.sender, tokenIds[sess.token]);
      tokenIds[sess.token] += 1;
    }

    // Only give rewards to coordinator if the erc721 can be transferred to the user
    rewards[sess.coordinator][sess.depositToken] += numberToMint * mintPrice;
  }

  /// @notice Allows a user to forgo their mint allocation
  /// @param sessionId The session Id
  /// @param amount The amount of deposits to withdraw
  function forgo(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == address(0)) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the minting period
    if (block.number > sess.mintingEnd || block.number < sess.mintingStart) {
      revert NonMinting(block.number, sess.mintingStart, sess.mintingEnd);
    }

    // Calculate the mint price before the user forgos their mint
    if(sess.resultPrice == 0) {
      sess.resultPrice = sess.depositAmount / sess.maxMintingAmount;
    }

    // Remove deposits
    // Will revert on underflow
    deposits[msg.sender][sessionId] -= amount;
    sess.depositAmount -= amount;
    IERC20(sess.depositToken).transfer(msg.sender, amount);
  }

  ////////////////////////////////////////////////////
  ///            SESSION MINTING PERIOD            ///
  ////////////////////////////////////////////////////

  /// @notice Helper function to get a session
  /// @param sessionId The uint256 session identifier
  /// @return A Session Object
  function getSession(uint256 sessionId) external returns(Session memory) {
    return sessions[sessionId];
  }
}
