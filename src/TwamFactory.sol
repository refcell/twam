// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {ERC721TokenReceiver} from "@solmate/tokens/ERC721.sol";
import {ClonesWithImmutableArgs} from "@clones/ClonesWithImmutableArgs.sol";

import {TwamBase} from "./TwamBase.sol";

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
error DuplicateSession(address sender, address approved, address token);

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
  using ClonesWithCallData for address;

  /// @dev Emit a creation event to track twams
  event TwamDeployed(TwamBase twam);

  /// @notice The TwamBase implementation
  TwamBase public immutable implementation;

  /// @dev Only addresses that have transferred the erc721 tokens to this address can create a session
  /// @dev Maps ERC721 => user
  mapping(address => address) private approvedCreator;

  /// @notice Tracks created TWAM sessions
  /// @dev Maps ERC721 => deployed TwamBase Contract
  mapping(address => address) public createdTwams;

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
  function createTWAM(
    address token,
    address coordinator,
    uint64 allocationStart,
    uint64 allocationEnd,
    uint64 mintingStart,
    uint64 mintingEnd,
    uint256 resultPrice,
    uint256 minPrice,
    uint256 depositAmount,
    uint256 maxMintingAmount,
    address depositToken,
    uint8 rolloverOption
  ) external returns (TwamBase twamBase) {
    // Prevent Overwriting Sessions
    if (createdTwams[token] == address(0) || token == address(0)) {
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

    bytes memory ptr = new bytes(101);
    assembly {
        // Pack 20 byte addresses
        mstore(add(ptr, 0x20), shl(0x60, token))
        mstore(add(ptr, 0x34), shl(0x60, coordinator))

        // Pack 8 byte uint64 values
        mstore(add(ptr, 0x48), shl(0xc0, allocationStart))
        mstore(add(ptr, 0x50), shl(0xc0, allocationEnd))
        mstore(add(ptr, 0x58), shl(0xc0, mintingStart))
        mstore(add(ptr, 0x60), shl(0xc0, mintingEnd))

        // Pack 32 byte uint256 values
        mstore(add(ptr, 0x68), resultPrice)
        mstore(add(ptr, 0x88), minPrice)
        mstore(add(ptr, 0xa8), depositAmount)
        mstore(add(ptr, 0xc8), maxMintingAmount)

        // Pack a 20 byte address and an 1 byte rollover option
        mstore(add(ptr, 0xe8), shl(0x60, depositToken))
        mstore(add(ptr, 0xfb), rolloverOption)
    }
    twamBase = TwamBase(
        address(implementation).cloneWithCallDataProvision(ptr)
    );
    emit TwamDeployed(twamBase);

    createdTwams[token] = address(twamBase);
  }

  /// @notice TwamFactory receives ERC721 tokens to allow permissionless session creation
  function onERC721Received(
        address _operator,
        address _from,
        uint256 _id,
        bytes calldata _data
    ) public virtual override returns (bytes4) {
      // TODO: extract the token from the bytes _data
      address token = address(_data);

      // Make sure there isn't already an approved creator
      if (approvedCreator[token] != address(0)) {
        revert SessionOverwrite();
      }

      // Verify this token is being transferred by checking the balance of _from
      if (IERC721(token).ownerOf(id) != _from) {
        revert SenderNotOwner();
      }

      // Approve the sender as the session creator for 
      approvedCreator[token] = _operator;

      // Finally, return the selector to complete the transfer
      return ERC721TokenReceiver.onERC721Received.selector;
    }
}