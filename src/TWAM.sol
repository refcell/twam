// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {IERC20} from "./interfaces/IERC20.sol";

/// Invalid Session
/// @param sessionId The session's id
error InvalidSession(uint256 sessionId);

/// Not during the Allocation Period
/// @param blockNumber block.number
/// @param allocationStart The block number that marks when the allocation starts
/// @param allocationEnd The block number that marks when the allocation ends
error NonAllocation(uint256 blockNumber, uint256 allocationStart, uint256 allocationEnd);

/// Not during the Minting Period
/// @param blockNumber block.number
/// @param mintingStart The block number that marks when the minting period starts
/// @param mintingEnd The block number that marks when the minting period ends
error NonMinting(uint256 blockNumber, uint256 mintingStart, uint256 mintingEnd);

/// Make sure the sender has enough deposits
/// @param sender The message sender
/// @param deposits The user's deposits in the session
/// @param amount The amount a user want's to mint with
error InsufficientDesposits(address sender, uint256 deposits, uint256 amount);

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
  address public owner;

  /// @notice Maps a user and session id to their deposits
  mapping(address => mapping(uint256 => uint256)) public deposits;

  constructor() {
    owner = msg.sender;
  }

  ////////////////////////////////////////////////////
  ///           SESSION MANAGEMENT LOGIC           ///
  ////////////////////////////////////////////////////

  /// @notice Creates a new twam session
  /// @dev Only the owner can create a twam session
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
    require(msg.sender == owner);
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
    if (sessionId >= nextSessionId || sessions[sessionId].token == 0) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    if (msg.sender != sess.coordinator) {
      InvalidCoordinator(msg.sender, sess.coordinator);
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

    }

    // Otherwise, do nothing.
    // If the session is closed, we just allow the users to withdraw
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
    if (sessionId >= nextSessionId || sessions[sessionId].token == 0) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the allocation period
    if (block.number > sess.allocationEnd || block.number < see.allocationStart) {
      revert NonAllocation(block.number, sess.allocationStart, sess.allocationEnd);
    }

    // Transfer the token to this contract
    IERC20(sess.token).transferFrom(msg.sender, address(this), amount);

    // Update the user's deposit amount and total session deposits
    deposits[msg.sender][sessionId] += amount;
    sess.depositAmount += amount;
  }

  /// @notice Withdraws a deposit token from a session
  /// @param sessionId The session id
  /// @param amount The amount of the deposit token to withdraw
  function withdraw(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == 0) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the allocation period
    if (
      (block.number > sess.allocationEnd || block.number < see.allocationStart)
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
    IERC20(sess.token).transferFrom(address(this), msg.sender, amount);
  }

  ////////////////////////////////////////////////////
  ///            SESSION MINTING PERIOD            ///
  ////////////////////////////////////////////////////

  /// @notice Mints tokens during minting period
  /// @param sessionId The session Id
  /// @param amount The amount of deposits to mint with
  function mint(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == 0) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session storage sess = sessions[sessionId];

    // Make sure the session is in the minting period
    if (block.number > sess.mintingEnd || block.number < see.mintingStart) {
      revert NonMinting(block.number, sess.mintingStart, sess.mintingEnd);
    }

    // Calculate the mint price
    uint256 resultPrice = sess.depositAmount / sess.maxMintingAmount;
    uint256 mintPrice = resultPrice > sess.minPrice ? resultPrice : sess.minPrice;

    // Make sure the user has enough deposits and can mint
    if (deposits[msg.sender][sessionId] < amount || amount < mintPrice) {
      revert InsufficientDesposits(msg.sender, deposits[msg.sender][sessionId], amount);
    }



  }

  /// @notice Allows a user to forgo their mint allocation
  /// @param sessionId The session Id
  /// @param amount The amount of deposits to withdraw
  function forgo(uint256 sessionId, uint256 amount) public {
    // Make sure the session is valid
    if (sessionId >= nextSessionId || sessions[sessionId].token == 0) {
      revert InvalidSession(sessionId);
    }

    // Get the session
    Session memory sess = sessions[sessionId];

    // Make sure the session is in the minting period
    if (block.number > sess.mintingEnd || block.number < see.mintingStart) {
      revert NonMinting(block.number, sess.mintingStart, sess.mintingEnd);
    }

    // Calculate the mint price
    uint256 resultPrice = sess.depositAmount / sess.maxMintingAmount;
    uint256 mintPrice = resultPrice > sess.minPrice ? resultPrice : sess.minPrice;

    // Make sure the user has enough deposits and can mint
    if (deposits[msg.sender][sessionId] < amount || amount < mintPrice) {
      revert InsufficientDesposits(msg.sender, deposits[msg.sender][sessionId], amount);
    }



  }
}
