// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

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

/// Require the ERC721 tokens to already be transferred to the twam contract
/// Enables permissionless session creation
/// @param balanceOfThis The ERC721 balance of the twam contract
/// @param maxMintingAmount The maxmum number of ERC721s to mint
error RequireMintedERC721Tokens(uint256 balanceOfThis, uint256 maxMintingAmount);

/// Bad Session Bounds
/// @param allocationStart The session's allocation period start
/// @param allocationEnd The session's allocation period end
/// @param mintingStart The session's minting period start
/// @param mintingEnd The session's minting period end
error BadSessionBounds(uint64 allocationStart, uint64 allocationEnd, uint64 mintingStart, uint64 mintingEnd);

////////////////////////////////////////////////////
///                     TWAM                     ///
////////////////////////////////////////////////////

/// @title TWAM
/// @notice Time Weighted Asset Mints
/// @author Andreas Bigger <andreas@nascent.xyz>
contract TWAM {
  /// @dev A mint session
  struct Session {
    /// @dev The token address
    address token;
    /// @dev The session coordinator
    address coordinator;
    /// @dev The start of the sessions's allocation
    uint64 allocationStart;
    /// @dev The end of the session's allocation period
    uint64 allocationEnd;
    /// @dev The start of the minting period
    uint64 mintingStart;
    /// @dev The end of the minting period
    uint64 mintingEnd;
    /// @dev The minting price, determined at the end of the allocation period.
    uint256 resultPrice;
    /// @dev The minimum price per token
    uint256 minPrice;
    /// @dev Deposit Token
    address depositToken;
    /// @dev Amount of deposit tokens
    uint256 depositAmount;
    /// @dev Maximum number of tokens to mint
    uint256 maxMintingAmount;
    /// @dev The Rollover option
    ///      1. Restart the twam
    ///      2. Mint at resulting price or minimum if not reached
    ///      3. Close Session
    uint256 rolloverOption;
  }

  /// @dev The next session id
  uint256 private nextSessionId;

  /// @dev Maps session ids to sessions
  mapping(uint256 => Session) public sessions;

  /// @dev This contract owner
  address immutable public owner;

  /// @notice Maps a user and session id to their deposits
  mapping(address => mapping(uint256 => uint256)) public deposits;

  /// @notice Session Rewards for Coordinators
  /// @dev Maps coordinator => token => rewardAmount
  mapping(address => mapping(address => uint256)) public rewards;

  /// @notice Token Ids for the ERC721s
  mapping(address => uint256) private tokenIds;

  constructor() {
    owner = msg.sender;
  }

  ////////////////////////////////////////////////////
  ///           SESSION MANAGEMENT LOGIC           ///
  ////////////////////////////////////////////////////

  /// @notice Creates a new twam session
  /// @dev This function is permissionless since we require
  /// @dev maxMintingAmount of `token` to be minted to this contract
  /// @param token The ERC721 Token
  /// @param coordinator The session coordinator who controls the session
  /// @param allocationStart When the allocation period begins
  /// @param allocationEnd When the allocation period ends
  /// @param mintingStart When the minting period begins
  /// @param mintingEnd When the minting period ends
  /// @param minPrice The minimum token price for minting
  /// @param depositToken The token to pay for minting
  /// @param maxMintingAmount The maximum amount of tokens to mint (must be minted to this contract)
  /// @param rolloverOption What happens when the minting period ends and the session is over; one of {1, 2, 3}
  function createSession(
    address token,
    address coordinator,
    uint64 allocationStart,
    uint64 allocationEnd,
    uint64 mintingStart,
    uint64 mintingEnd,
    uint256 minPrice,
    address depositToken,
    uint256 maxMintingAmount,
    uint256 rolloverOption
  ) public {
    // To allow permissionless session creation, the erc721 tokens must be minted or transferred to this contract
    // This can be enabled efficiently by setting the ERC721.balanceOf(address(TWAM)) to the maxMintingAmount on erc721 contract deployment
    uint256 balanceOfThis = IERC721(token).balanceOf(address(this));
    if (balanceOfThis < maxMintingAmount) revert RequireMintedERC721Tokens(balanceOfThis, maxMintingAmount);

    // Validate Session Bounds
    if (
      allocationStart > allocationEnd
      || mintingStart > mintingEnd
      || mintingStart < allocationEnd
    ) {
      revert BadSessionBounds(allocationStart, allocationEnd, mintingStart, mintingEnd);
    }

    uint256 currentSessionId = nextSessionId;
    nextSessionId += 1;
    sessions[currentSessionId] = Session(
      token, coordinator, allocationStart, allocationEnd,
      mintingStart, mintingEnd,
      0, // resultPrice
      minPrice, depositToken,
      0, // depositAmount
      maxMintingAmount, rolloverOption
    );
  }

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

    // Remove deposits
    // Will revert on underflow
    deposits[msg.sender][sessionId] -= amount;
    sess.depositAmount -= amount;
    IERC20(sess.depositToken).transferFrom(address(this), msg.sender, amount);
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
