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
    MockERC721 public badMockERC721;  // Mock Invalid ERC721 Token

    /// @dev Twam Session Arguments
    MockERC721 public mockToken;      // Mock ERC721 Token
    address public constant COORDINATOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
    uint64 public allocationStart;
    uint64 public allocationEnd;
    uint64 public mintingStart;
    uint64 public mintingEnd;
    uint256 public minPrice; 
    MockERC20 public depositToken;    // Mock ERC20 Deposit Token
    uint256 public constant TOKEN_SUPPLY = 10_000;
    uint256 public maxMintingAmount = TOKEN_SUPPLY;
    uint8 public rolloverOption;

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
        address(mockToken),       // token
        COORDINATOR,              // coordinator
        allocationStart = t + 10, // allocationStart,
        allocationEnd = t + 15,   // allocationEnd,
        mintingStart = t + 20,    // mintingStart,
        mintingEnd = t + 25,      // mintingEnd,
        minPrice = 100,           // minPrice,
        address(depositToken),    // depositToken
        TOKEN_SUPPLY,             // maxMintingAmount,
        rolloverOption = 1        // rolloverOption
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

  /// @notice Tests reading the Allocation Start from Immutable Args
  function testReadAllocationStart() public {
    uint64 read_alloc_start = twamBase.readAllocationStart();
    assert(read_alloc_start == allocationStart);
  }

  /// @notice Tests reading the Allocation End from Immutable Args
  function testReadAllocationEnd() public {
    uint64 read_alloc_end = twamBase.readAllocationEnd();
    assert(read_alloc_end == allocationEnd);
  }

  /// @notice Tests reading the Minting Start from Immutable Args
  function testReadMintingStart() public {
    uint64 read_minting_start = twamBase.readMintingStart();
    assert(read_minting_start == mintingStart);
  }

  /// @notice Tests reading the Minting End from Immutable Args
  function testReadMintingEnd() public {
    uint64 read_minting_end = twamBase.readMintingEnd();
    assert(read_minting_end == mintingEnd);
  }

  /// @notice Tests reading the Min Price from Immutable Args
  function testReadMinPrice() public {
    uint256 read_min_price = twamBase.readMinPrice();
    assert(read_min_price == minPrice);
  }

  /// @notice Tests reading the Maximum Minting Amount from Immutable Args
  function testReadMaxMintingAmount() public {
    uint256 read_max_minting_amount = twamBase.readMaxMintingAmount();
    assert(read_max_minting_amount == maxMintingAmount);
  }

  /// @notice Tests reading the Deposit Token from Immutable Args
  function testReadDepositToken() public {
    address read_deposit_token = twamBase.readDepositToken();
    assert(read_deposit_token == address(depositToken));
  }

  /// @notice Tests reading the Rollover Option from Immutable Args
  function testReadRolloverOption() public {
    uint8 read_rollover_option = twamBase.readRolloverOption();
    assert(read_rollover_option == rolloverOption);
  }

  /// @notice Tests reading the Session Id from Immutable Args
  function testReadSessionId() public {
    uint256 read_session_id = twamBase.readSessionId();
    assert(read_session_id == 1);
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