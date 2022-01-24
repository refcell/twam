// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {ERC721TokenReceiver} from "@solmate/tokens/ERC721.sol";
import {ClonesWithImmutableArgs} from "@clones/ClonesWithImmutableArgs.sol";

import {TwamBase} from "./TwamBase.sol";
import {IERC721} from "./interfaces/IERC721.sol";

////////////////////////////////////////////////////
///                 CUSTOM ERRORS                ///
////////////////////////////////////////////////////

/// Duplicate Session
/// @param sender The message sender
/// @param token The address of the ERC721 Token
error DuplicateSession(address sender, address token);

/// Not Approved
/// The sender is not approved to create the session for the given ERC721 token
/// @param sender The message sender
/// @param approved The address of the approved creator
/// @param token The address of the ERC721 Token
error NotApproved(address sender, address approved, address token);

/// Bad Session Bounds
/// @param allocationStart The session's allocation period start
/// @param allocationEnd The session's allocation period end
/// @param mintingStart The session's minting period start
/// @param mintingEnd The session's minting period end
error BadSessionBounds(uint64 allocationStart, uint64 allocationEnd, uint64 mintingStart, uint64 mintingEnd);

/// Require the ERC721 tokens to already be transferred to the twam contract
/// Enables permissionless session creation
/// @param balanceOfThis The ERC721 balance of the twam contract
/// @param maxMintingAmount The maxmum number of ERC721s to mint
error RequireMintedERC721Tokens(uint256 balanceOfThis, uint256 maxMintingAmount);

/// Session Overwrite
error SessionOverwrite();

/// Sender is not owner
error SenderNotOwner();

////////////////////////////////////////////////////
///                 Twam Factory                 ///
////////////////////////////////////////////////////

/// @title TwamFactory
/// @notice TWAM Deployment Factory
/// @author Andreas Bigger <andreas@nascent.xyz>
/// @dev Adapted from https://github.com/ZeframLou/vested-erc20/blob/main/src/VestedERC20Factory.sol
contract TwamFactory is ERC721TokenReceiver {
  /// @dev Use CloneWithCallData library for cheap deployment
  /// @dev Uses a modified minimal proxy pattern
  using ClonesWithImmutableArgs for address;

  /// @dev Emit a creation event to track twams
  event TwamDeployed(TwamBase twam);

  /// @notice The TwamBase implementation
  TwamBase public immutable implementation;

  /// @dev Only addresses that have transferred the erc721 tokens to this address can create a session
  /// @dev Maps ERC721 => user
  mapping(address => address) public approvedCreator;

  /// @notice Tracks created TWAM sessions
  /// @dev Maps ERC721 => deployed TwamBase Contract
  mapping(address => address) public createdTwams;

  /// @notice Tracks TWAM Sessions by ID
  mapping(uint256 => address) public sessions;

  /// @notice The next session ID
  uint256 public sessionId = 1;

  /// @notice Creates the Factory with the given TwamBase implementation
  /// @param implementation_ The TwamBase implementation
  constructor(TwamBase implementation_) {
    implementation = implementation_;
  }

  /// @notice Creates a TWAM
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
  function createTwam(
    address token,
    address coordinator,
    uint64 allocationStart,
    uint64 allocationEnd,
    uint64 mintingStart,
    uint64 mintingEnd,
    uint256 minPrice,
    address depositToken,
    uint256 maxMintingAmount,
    uint8 rolloverOption
  ) external returns (TwamBase twamBase) {
    // Prevent Overwriting Sessions
    if (createdTwams[token] != address(0) || token == address(0)) {
      revert DuplicateSession(msg.sender, token);
    }

    // For Permissionless Session Creation
    // We check that the sender is the approvedCreator
    if (approvedCreator[token] != msg.sender) {
      revert NotApproved(msg.sender, approvedCreator[token], token);
    }

    // We also have to make sure this address has a sufficient balance of ERC721 tokens for the session
    // This can be done by setting the ERC721.balanceOf(address(TwamFactory)) to the maxMintingAmount on ERC721 contract deployment
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

    // We can abi encodePacked instead of manually packing
    bytes memory data = abi.encodePacked(
      token,
      coordinator,
      allocationStart,
      allocationEnd,
      mintingStart,
      mintingEnd,
      minPrice,
      maxMintingAmount,
      depositToken,
      rolloverOption,
      sessionId
    );

    // Create the TWAM
    twamBase = TwamBase(
        address(implementation).clone(data)
    );
    emit TwamDeployed(twamBase);

    // Record Creation
    createdTwams[token] = address(twamBase);
    sessions[sessionId] = address(twamBase);
    sessionId += 1;
  }

  /// @notice TwamFactory receives ERC721 tokens to allow permissionless session creation
  function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes memory _data
    ) public virtual override returns (bytes4) {
      // bytes memory data;
      // address token;
      // assembly {
      //   token := mload(calldataload(_data.offset))
      // }
      // uint256 length = _data.length;
      // assembly {
      //   length := calldataload(_data.offset).length
      // }
      // if (length > 32) revert SessionOverwrite();
      address token = abi.decode(_data, (address));

      // Make sure there isn't already an approved creator
      if (approvedCreator[token] != address(0)) {
        revert SessionOverwrite();
      }

      // Verify this token is being transferred by checking the balance of _from
      // if (IERC721(token).ownerOf(_id) != _from) {
      //   revert SenderNotOwner();
      // }

      // Approve the sender as the session creator for 
      approvedCreator[token] = _from;

      // Finally, return the selector to complete the transfer
      return ERC721TokenReceiver.onERC721Received.selector;
    }
}