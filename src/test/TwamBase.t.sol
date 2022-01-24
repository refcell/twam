// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;


import {stdCheats, stdError} from "@std/stdlib.sol";
import {Vm} from "@std/Vm.sol";

import {MockERC20} from "@solmate/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "@solmate/test/utils/mocks/MockERC721.sol";
import {SafeCastLib} from "@solmate/utils/SafeCastLib.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {TwamBase} from "../TwamBase.sol";
import {TwamFactory} from "../TwamFactory.sol";

/// @dev DSTestPlus inherits stdCheats
contract TwamBaseTest is DSTestPlus {

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
      
      // Create the TWAM Session
      uint64 t = SafeCastLib.safeCastTo64(block.timestamp);
      startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
      mockToken.mint(COORDINATOR, 0);
      mockToken.approve(COORDINATOR, 0);
      mockToken.safeTransferFrom(
        COORDINATOR,                          // from
        address(twamFactory),                 // to
        0,                                    // id
        abi.encode(address(mockToken))        // data
      );
      for(uint256 i = 1; i < TOKEN_SUPPLY; i++) {
          mockToken.mint(address(twamFactory), i);
      }
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
    }






  ////////////////////////////////////////////////////
  ///            READ SESSION PARAMETERS           ///
  ////////////////////////////////////////////////////

  /// @notice Tests reading the ERC721 Token from Immutable Args
  function testReadToken() public {
    address read_token = twamBase.readToken();
    assertEq(read_token, address(mockToken));
  }

  /// @notice Tests reading the Coordinator from Immutable Args
  function testReadCoordinator() public {
    address read_coordinator = twamBase.readCoordinator();
    assertEq(read_coordinator, COORDINATOR);
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