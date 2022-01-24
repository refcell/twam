// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;


import {stdError} from "@std/stdlib.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";
import {SafeCastLib} from "@solmate/utils/SafeCastLib.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {TwamBase} from "../TwamBase.sol";
import {TwamFactory} from "../TwamFactory.sol";

/// @dev DSTestPlus inherits stdCheats
contract TwamFactoryTest is DSTestPlus {

    /// @dev Contracts
    TwamBase public twamBase;         // Twam Base (Clone)
    TwamFactory public twamFactory;   // Twam Factory
    MockERC20 public depositToken;    // Mock ERC20 Deposit Token
    MockERC721 public badMockERC721;  // Mock Invalid ERC721 Token
    MockERC721 public mockToken;      // Mock ERC721 Token

    /// @dev Constants
    uint256 public constant TOKEN_SUPPLY = 10_000;
    address public constant COORDINATOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    /// @notice Testing suite precursors
    function setUp() public {
        TwamBase exampleClone = new TwamBase();
        twamFactory = new TwamFactory(exampleClone);

        // Creat Mock Tokens
        depositToken = new MockERC20("Token", "TKN", 18);
        mockToken = new MockERC721("Token", "TKN");
        badMockERC721 = new MockERC721("Token", "TKN");
    }

    /// @notice Test onERC721Received
    function testOnERC721Received() public {
      startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
      
      mockToken.mint(COORDINATOR, 0);

      // This should work
      mockToken.approve(COORDINATOR, 0);
      mockToken.safeTransferFrom(
        COORDINATOR,                          // from
        address(twamFactory),                 // to
        0,                                    // id
        abi.encode(address(mockToken))        // data
      );

      // Verify we correctly set the approved creator
      assert(twamFactory.approvedCreator(address(mockToken)) != address(0));
      assert(twamFactory.approvedCreator(address(mockToken)) == COORDINATOR);
      
      // This should fail since the session has already been created
      vm.expectRevert("WRONG_FROM");
      mockToken.transferFrom(COORDINATOR, address(twamFactory), 0);

      vm.stopPrank();
    }

    /// @notice Creates a Twam from Factory
    function testCreateTwam() public {
      uint64 t = SafeCastLib.safeCastTo64(block.timestamp);

      // Transfer the NFT to verify ownership
      startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
      mockToken.mint(COORDINATOR, 0);
      mockToken.approve(COORDINATOR, 0);
      mockToken.safeTransferFrom(
        COORDINATOR,                          // from
        address(twamFactory),                 // to
        0,                                    // id
        abi.encode(address(mockToken))        // data
      );
      vm.stopPrank();

      // We should expect a NotApproved revert when not from the COORDINATOR
      vm.expectRevert(abi.encodeWithSignature(
        "NotApproved(address,address,address)",
        address(this),      // Msg Sender
        COORDINATOR,        // Approved Creator
        address(mockToken)  // ERC721 Token
      ));
      twamBase = twamFactory.createTwam(
        address(mockToken),     // token
        COORDINATOR,            // coordinator
        t + 10,                 // allocationStart,
        t + 15,                 // allocationEnd,
        t + 20,                 // mintingStart,
        t + 25,                 // mintingEnd,
        100,                    // minPrice,
        address(depositToken),  // depositToken
        TOKEN_SUPPLY,           // maxMintingAmount,
        1                       // rolloverOption
      );

      // Switch back to COORDINATOR context
      startHoax(COORDINATOR, COORDINATOR, type(uint256).max);

      // Should still fail without senting the MaxMintingAmount
      vm.expectRevert(abi.encodeWithSignature(
        "RequireMintedERC721Tokens(uint256,uint256)",
        1,
        TOKEN_SUPPLY
      ));
      twamBase = twamFactory.createTwam(
        address(mockToken),     // token
        COORDINATOR,            // coordinator
        t + 10,                 // allocationStart,
        t + 15,                 // allocationEnd,
        t + 20,                 // mintingStart,
        t + 25,                 // mintingEnd,
        100,                    // minPrice,
        address(depositToken),  // depositToken
        TOKEN_SUPPLY,           // maxMintingAmount,
        1                       // rolloverOption
      );

      // Mint all erc721 tokens to the twam factory
      // This can be practically done by modifying the twam factory to be the initial owner
      for(uint256 i = 1; i < TOKEN_SUPPLY; i++) {
          mockToken.mint(address(twamFactory), i);
      }

      // Successfully create a TWAM session
      twamBase = twamFactory.createTwam(
        address(mockToken),     // token
        COORDINATOR,            // coordinator
        t + 10,                 // allocationStart,
        t + 15,                 // allocationEnd,
        t + 20,                 // mintingStart,
        t + 25,                 // mintingEnd,
        100,                    // minPrice,
        address(depositToken),  // depositToken
        TOKEN_SUPPLY,           // maxMintingAmount,
        1                       // rolloverOption
      );

      vm.stopPrank();

      // Fail to create a duplicate session
      vm.expectRevert(abi.encodeWithSignature(
        "DuplicateSession(address,address)",
        address(this),
        address(mockToken)
      ));
      twamBase = twamFactory.createTwam(
        address(mockToken),     // token
        COORDINATOR,            // coordinator
        t + 10,                 // allocationStart,
        t + 15,                 // allocationEnd,
        t + 20,                 // mintingStart,
        t + 25,                 // mintingEnd,
        100,                    // minPrice,
        address(depositToken),  // depositToken
        TOKEN_SUPPLY,           // maxMintingAmount,
        1                       // rolloverOption
      );

      // Make sure factory state updates
      assert(twamFactory.createdTwams(address(mockToken)) != address(0));
      assert(twamFactory.sessions(1) != address(0));
      assert(twamFactory.sessionId() == 2);
    }
}