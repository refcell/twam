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
  TwamBase public exampleClone = new TwamBase();

  /// @dev Twam Session Arguments
  MockERC721 public mockToken;      // Mock ERC721 Token
  address public constant COORDINATOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;
  uint64 public recordedTimestamp;
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
    twamFactory = new TwamFactory(exampleClone);

    // Creat Mock Tokens
    depositToken = new MockERC20("Token", "TKN", 18);
    mockToken = new MockERC721("Token", "TKN");
    badMockERC721 = new MockERC721("Token", "TKN");
    
    // Create the TWAM Session
    uint64 t = SafeCastLib.safeCastTo64(block.timestamp);
    recordedTimestamp = t;
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
      minPrice = 1,             // minPrice,
      address(depositToken),    // depositToken
      TOKEN_SUPPLY,             // maxMintingAmount,
      rolloverOption = 1        // rolloverOption
    );
    vm.stopPrank();
  }

  ////////////////////////////////////////////////////
  ///           SESSION MANAGEMENT LOGIC           ///
  ////////////////////////////////////////////////////

  /// @notice Tests rolling over a session
  function testRollover() public {
    vm.warp(recordedTimestamp);

    // Expect Revert when not called from the coordinator context
    vm.expectRevert(
      abi.encodeWithSignature(
        "InvalidCoordinator(address,address)",
        address(this),
        COORDINATOR
      )
    );
    twamBase.rollover();

    // Hoax from the COORDINATOR context
    startHoax(COORDINATOR, COORDINATOR, type(uint256).max);

    // Expect Revert when the mint isn't over
    vm.expectRevert(
      abi.encodeWithSignature(
        "MintingNotOver(uint256,uint64)",
        recordedTimestamp,
        mintingEnd
      )
    );
    twamBase.rollover();

    // Roll the block height
    vm.warp(mintingEnd);

    // The rollover should succeed now that the minting period is over
    twamBase.rollover();

    vm.stopPrank();
  }

  /// @notice Coordinators are able to withdraw their rewards
  function testWithdrawRewards() public {
    // Jump to allocation period
    vm.warp(allocationStart);

    // Create Mock Users
    address firstUser = address(1);
    address secondUser = address(2);

    // Give them depositToken balances
    depositToken.mint(firstUser, 1e18);
    depositToken.mint(secondUser, 1e18);

    // Mock first user deposits
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18); // Approve the TWAM to transfer the depositToken
    twamBase.deposit(TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == TOKEN_SUPPLY);
    vm.stopPrank();

    // Mock second user deposits
    startHoax(secondUser, secondUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18); // Approve the TWAM to transfer the depositToken
    twamBase.deposit(TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);
    vm.stopPrank();

    // Jump to minting period
    vm.warp(mintingStart);

    // Mock first user mints
    startHoax(firstUser, firstUser, type(uint256).max);
    twamBase.mint(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY / 2);
    assert(mockToken.balanceOf(address(firstUser)) == TOKEN_SUPPLY / 2);
    assert(twamBase.rewards(COORDINATOR, address(depositToken)) == TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);
    vm.stopPrank();

    // Mock second user mints
    startHoax(secondUser, secondUser, type(uint256).max);
    twamBase.mint(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == 0);
    assert(mockToken.balanceOf(address(secondUser)) == TOKEN_SUPPLY / 2);
    assert(twamBase.rewards(COORDINATOR, address(depositToken)) == 2 * TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);
    vm.stopPrank();

    // Jump to post-mint
    vm.warp(mintingEnd);

    // Try to withdraw rewards
    startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
    assert(depositToken.balanceOf(COORDINATOR) == 0);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);
    assert(twamBase.rewards(COORDINATOR, address(depositToken)) == 2 * TOKEN_SUPPLY);
    twamBase.withdrawRewards();
    assert(depositToken.balanceOf(COORDINATOR) == 2 * TOKEN_SUPPLY);
    vm.stopPrank();
  }

  ////////////////////////////////////////////////////
  ///           SESSION ALLOCATION PERIOD          ///
  ////////////////////////////////////////////////////

  /// @notice Test deposits
  function testDeposit() public {
    // Jump to after the allocation period
    vm.warp(allocationEnd + 1);

    // Expect Revert when we are after the allocation period
    vm.expectRevert(
        abi.encodeWithSignature(
            "NonAllocation(uint256,uint64,uint64)",
            allocationEnd + 1,
            allocationStart,
            allocationEnd
        )
    );
    twamBase.deposit(TOKEN_SUPPLY);

    // Reset to before the allocation period
    vm.warp(allocationStart - 1);

    // Expect Revert when we are before the allocation period
    vm.expectRevert(
        abi.encodeWithSignature(
            "NonAllocation(uint256,uint64,uint64)",
            allocationStart - 1,
            allocationStart,
            allocationEnd
        )
    );
    twamBase.deposit(TOKEN_SUPPLY);

    // Jump to allocation period
    vm.warp(allocationStart);

    // Create Mock Users
    address firstUser = address(1);
    address secondUser = address(2);

    // Give them depositToken balances
    depositToken.mint(firstUser, 1e18);
    depositToken.mint(secondUser, 1e18);

    // Mock first user deposits
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18); // Approve the twamBase to transfer the depositToken
    twamBase.deposit(TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == TOKEN_SUPPLY);
    vm.stopPrank();

    // Mock second user deposits
    startHoax(secondUser, secondUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18); // Approve the twamBase to transfer the depositToken
    twamBase.deposit(TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);
    vm.stopPrank();
  }

  /// @notice Tests users can withdraw after minting ends when session rollover = 3
  function testWithdrawals() public {
    // Replicate Base Variables
    TwamFactory twamFactory2 = new TwamFactory(exampleClone);

    // Creat Mock Tokens
    MockERC20 depositToken2 = new MockERC20("Token", "TKN", 18);
    MockERC721 mockToken2 = new MockERC721("Token", "TKN");

    // Create a rollover=3 TWAM Session
    uint64 t = SafeCastLib.safeCastTo64(block.timestamp);
    recordedTimestamp = t;
    startHoax(COORDINATOR, COORDINATOR, type(uint256).max);
    mockToken2.mint(COORDINATOR, 0);
    mockToken2.approve(COORDINATOR, 0);
    mockToken2.safeTransferFrom(
      COORDINATOR,                           // from
      address(twamFactory2),                 // to
      0,                                     // id
      abi.encode(address(mockToken2))        // data
    );
    for(uint256 i = 1; i < TOKEN_SUPPLY; i++) {
        mockToken2.mint(address(twamFactory2), i);
    }
    TwamBase twamBase2 = twamFactory2.createTwam(
      address(mockToken2),      // token
      COORDINATOR,              // coordinator
      t + 10,                   // allocationStart,
      t + 15,                   // allocationEnd,
      t + 20,                   // mintingStart,
      t + 25,                   // mintingEnd,
      1,                        // minPrice,
      address(depositToken2),   // depositToken
      TOKEN_SUPPLY,             // maxMintingAmount,
      3                         // rolloverOption
    );
    vm.stopPrank();

    // Jump to allocation period
    vm.warp(t + 10);

    // Create Mock Users
    address firstUser = address(1);
    depositToken2.mint(firstUser, 1e18);

    // Mock user deposits
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken2.approve(address(twamBase2), 1e18); // Approve the twamBase2 to transfer the depositToken2
    twamBase2.deposit(TOKEN_SUPPLY);
    assert(depositToken2.balanceOf(address(twamBase2)) == TOKEN_SUPPLY);
    vm.stopPrank();

    // Jump to after the mint period
    vm.warp(t + 26);

    // Mock user withdrawal
    startHoax(firstUser, firstUser, type(uint256).max);
    assert(depositToken2.balanceOf(address(twamBase2)) == TOKEN_SUPPLY);
    twamBase2.withdraw(TOKEN_SUPPLY);
    assert(depositToken2.balanceOf(address(twamBase2)) == 0);
    vm.stopPrank();
  }

  ////////////////////////////////////////////////////
  ///            SESSION MINTING PERIOD            ///
  ////////////////////////////////////////////////////

  /// @notice Tests minting period
  function testMints() public {
    // Jump to allocation period
    vm.warp(allocationStart);

    // Create Users
    address firstUser = address(1);
    address secondUser = address(2);
    depositToken.mint(firstUser, 1e18);
    depositToken.mint(secondUser, 1e18);

    // Users Deposit
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);
    vm.stopPrank();
    startHoax(secondUser, secondUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);

    // User can't mint before minting period starts
    vm.expectRevert(
      abi.encodeWithSignature(
        "NonMinting(uint256,uint64,uint64)",
        allocationStart,
        mintingStart,
        mintingEnd
    ));
    twamBase.mint(TOKEN_SUPPLY);

    vm.stopPrank();

    // Jump to minting period
    vm.warp(mintingStart);

    // Mock first user mints
    startHoax(firstUser, firstUser, type(uint256).max);

    // User shouldn't be able to mint more than their deposits
    vm.expectRevert(
      abi.encodeWithSignature(
        "InsufficientDesposits(address,uint256,uint256)",
        firstUser,
        TOKEN_SUPPLY,
        2 * TOKEN_SUPPLY
      )
    );
    twamBase.mint(2 * TOKEN_SUPPLY);

    // Then they should successfully be able to mint
    twamBase.mint(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY / 2);
    assert(mockToken.balanceOf(address(firstUser)) == TOKEN_SUPPLY / 2);
    assert(twamBase.rewards(COORDINATOR, address(depositToken)) == TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);

    // Check that the session `resultPrice` is correct
    assert(twamBase.resultPrice(1) == 2);
    vm.stopPrank();

    // Mock second user mints
    startHoax(secondUser, secondUser, type(uint256).max);

    // User shouldn't be able to mint more than their deposits
    vm.expectRevert(abi.encodeWithSignature(
        "InsufficientDesposits(address,uint256,uint256)",
        secondUser, TOKEN_SUPPLY, 2 * TOKEN_SUPPLY
    ));
    twamBase.mint(2 * TOKEN_SUPPLY);

    twamBase.mint(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == 0);
    assert(mockToken.balanceOf(address(secondUser)) == TOKEN_SUPPLY / 2);
    assert(twamBase.rewards(COORDINATOR, address(depositToken)) == 2 * TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) == 2 * TOKEN_SUPPLY);

    // Check that the session `resultPrice` is still correct
    assert(twamBase.resultPrice(1) == 2);

    vm.stopPrank();
  }

  /// @notice Tests forgoing a mint
  function testForgo() public {
    // Jump to allocation period
    vm.warp(allocationStart);

    // Create Users
    address firstUser = address(1);
    address secondUser = address(2);
    depositToken.mint(firstUser, 1e18);
    depositToken.mint(secondUser, 1e18);

    // Users Deposit
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);
    vm.stopPrank();
    startHoax(secondUser, secondUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);

    // User can't forgo before minting period starts
    vm.expectRevert(abi.encodeWithSignature(
        "NonMinting(uint256,uint64,uint64)",
        allocationStart,
        mintingStart,
        mintingEnd
    ));
    twamBase.forgo(TOKEN_SUPPLY);

    vm.stopPrank();

    // Jump to minting period
    vm.warp(mintingStart);

    // Mock first user forgos
    startHoax(firstUser, firstUser, type(uint256).max);

    // Then they should successfully be able to forgo
    twamBase.forgo(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(firstUser)) == 0);
    assert(depositToken.balanceOf(address(twamBase)) == TOKEN_SUPPLY);

    // Check that the session `resultPrice` is correct
    assert(twamBase.resultPrice(1) == 2);
    vm.stopPrank();

    // Mock second user forgos
    startHoax(secondUser, secondUser, type(uint256).max);

    twamBase.forgo(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(secondUser)) == 0);
    assert(depositToken.balanceOf(address(twamBase)) == 0);

    // Check that the session `resultPrice` is still correct
    assert(twamBase.resultPrice(1) == 2);
    vm.stopPrank();
  }

  /// @notice Tests forgoing a mint with a loss penalty
  function testForgoWithLossPenalty() public {
    // Jump to the middle of the allocation period
    vm.warp(allocationEnd - allocationStart + allocationStart);

    // Create Users
    address firstUser = address(1);
    address secondUser = address(2);
    depositToken.mint(firstUser, 1e18);
    depositToken.mint(secondUser, 1e18);

    // Users Deposit
    startHoax(firstUser, firstUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);
    vm.stopPrank();
    startHoax(secondUser, secondUser, type(uint256).max);
    depositToken.approve(address(twamBase), 1e18);
    twamBase.deposit(TOKEN_SUPPLY);

    // User can't forgo before minting period starts
    vm.expectRevert(abi.encodeWithSignature(
        "NonMinting(uint256,uint64,uint64)",
        allocationEnd - allocationStart + allocationStart,
        mintingStart,
        mintingEnd
    ));
    twamBase.forgo(TOKEN_SUPPLY);

    vm.stopPrank();

    // Jump to minting period
    vm.warp(mintingStart);

    // Mock first user forgos
    startHoax(firstUser, firstUser, type(uint256).max);

    // Then they should successfully be able to forgo
    twamBase.forgo(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(firstUser)) == 0);

    // Check that the loss penalty came into effect
    // assert(depositToken.balanceOf(firstUser) == TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) >= TOKEN_SUPPLY);

    // Check that the session `resultPrice` is correct
    assert(twamBase.resultPrice(1) == 2);
    vm.stopPrank();

    // Mock second user forgos
    startHoax(secondUser, secondUser, type(uint256).max);

    twamBase.forgo(TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(twamFactory)) == TOKEN_SUPPLY);
    assert(mockToken.balanceOf(address(secondUser)) == 0);

    // Check the loss penalty
    assert(depositToken.balanceOf(secondUser) < TOKEN_SUPPLY);
    assert(depositToken.balanceOf(address(twamBase)) >= 0);

    // Check that the session `resultPrice` is still correct
    assert(twamBase.resultPrice(1) == 2);
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

  /// @notice Tests reading the Twam Factory Address from Immutable Args
  function testReadTwamFactoryAddress() public {
    address read_twam_factory_addr = twamBase.readTwamFactoryAddress();
    assert(read_twam_factory_addr == address(twamFactory));
  }
}