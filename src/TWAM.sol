// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {IERC20} from "./interfaces/IERC20.sol";

/// Invalid Session
/// @param sessionId The session's id
error InvalidSession(uint256 sessionId);

/// Allocation Period is over
/// @param blockNumber block.number
/// @param allocationEnd The block number that marks when the allocation ends
error AllocationEnded(uint256 blockNumber, uint256 allocationEnd);

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

  ////////////////////////////////////////////////////
  ///           SESSION INTERACTION LOGIC          ///
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

    // Make sure the session is not in the minting period
    if (block.number > sess.allocationEnd) {
      revert AllocationEnded(block.number, sess.allocationEnd);
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

    // Make sure the session is not after the allocation end
    if (block.number > sess.allocationEnd) {
      revert AllocationEnded(block.number, sess.allocationEnd);
    }

    // Update the user's deposit amount and total session deposits
    // This will revert on underflow so no need to check amount
    deposits[msg.sender][sessionId] -= amount;
    sess.depositAmount -= amount;

    // Transfer the token to this contract
    IERC20(sess.token).transferFrom(address(this), msg.sender, amount);
  }
}
