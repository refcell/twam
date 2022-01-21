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

        // Mint all erc721 tokens to the twam
        // for(uint256 i = 1; i < TOKEN_SUPPLY; i++) {
            // mockToken.mint(address(twamFactory), i);
        // }
        // Save the first token to transfer to set the permissioned session creator
  
        // mockToken.mint(COORDINATOR, 0);
        // mockToken.transfer(address(twamFactory), 0);
    }

    /// @notice Test onERC721Received
    function testOnERC721Received() public {
      startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
      
      mockToken.mint(COORDINATOR, 0);

      // This should work
      mockToken.approve(COORDINATOR, 0);
      // vm.expectRevert(abi.encodeWithSignature("SessionOverwrite()"));
      mockToken.safeTransferFrom(
        COORDINATOR,                          // from
        address(twamFactory),                 // to
        0,                                    // id
        abi.encode(address(mockToken))  // data
      );

      // Verify we correctly set the approved creator

      // assert(twamFactory.approvedCreator(address(mockToken)) != address(0));
      // assert(twamFactory.approvedCreator(address(mockToken)) == COORDINATOR);
      
      // This should fail since the session has already been created
      // vm.expectRevert(abi.encodeWithSignature("SessionOverwrite()"));
      // mockToken.transferFrom(COORDINATOR, address(twamFactory), 0);

      vm.stopPrank();
    }

    /// @notice Creates a Twam from Factory
    function xtestCreateTwam() public {
      uint64 t = SafeCastLib.safeCastTo64(block.timestamp);

      // We should expect a NotApproved revert
      // vm.expectRevert(abi.encodeWithSignature(
      //   "NotApproved(address,address,address)",
      //   address(this),
      //   address(0),
      //   address(mockToken)
      // ));



      // vm.expectRevert(abi.encodeWithSignature(
      //   "DuplicateSession(address,address)",
      //   address(this),
      //   address(mockToken)
      // ));

      vm.expectRevert(abi.encodeWithSignature(
        "RequireMintedERC721Tokens(uint256,uint256)",
        TOKEN_SUPPLY - 1,
        TOKEN_SUPPLY
      ));
      twamBase = twamFactory.createTwam(
        address(mockToken),
        COORDINATOR,
        t + 10, // allocationStart,
        t + 15, // allocationEnd,
        t + 20, // mintingStart,
        t + 25, // mintingEnd,
        100, // minPrice,
        address(depositToken),
        TOKEN_SUPPLY, // maxMintingAmount,
        1 // rolloverOption
      );
    }

    ////////////////////////////////////////////////////
    ///           SESSION MANAGEMENT LOGIC           ///
    ////////////////////////////////////////////////////

    ////////////////////////////////////////////////////
    ///           SESSION ALLOCATION PERIOD          ///
    ////////////////////////////////////////////////////

    ////////////////////////////////////////////////////
    ///            SESSION MINTING PERIOD            ///
    ////////////////////////////////////////////////////

    ////////////////////////////////////////////////////
    ///            SESSION MINTING PERIOD            ///
    ////////////////////////////////////////////////////

}