// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;


import {stdCheats, stdError} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {MockERC721} from "solmate/test/utils/mocks/MockERC721.sol";
import {SafeCastLib} from "solmate/utils/SafeCastLib.sol";

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {TWAM} from "../TWAM.sol";

contract TWAMTest is DSTestPlus, stdCheats {

    /// @dev Use forge-std Vm logic
    Vm public constant vm = Vm(HEVM_ADDRESS);

    /// @dev The TWAM Contract
    TWAM public twam;

    /// @dev The max number of tokens to be minted
    uint256 public constant TOKEN_SUPPLY = 10_000;

    /// @dev The Mock ERC721 Contract
    MockERC721 public mockToken;

    /// @notice VB is the one true coordinatooor
    address public constant COORDINATOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    /// @dev The Mock ERC20 Deposit Token
    MockERC20 public depositToken;

    /// @notice testing suite precursors
    function setUp() public {
        /// @dev sets address(this) as the owner of the TWAM contract
        twam = new TWAM();
        assert(twam.owner() == address(this));

        depositToken = new MockERC20("Token", "TKN", 18);
        mockToken = new MockERC721("Token", "TKN");
    }

    ////////////////////////////////////////////////////
    ///           SESSION MANAGEMENT LOGIC           ///
    ////////////////////////////////////////////////////

    /// @notice test creating a twam session
    function testCreateSession() public {
        uint64 blockNumber = SafeCastLib.safeCastTo64(block.number);

        // Hoax the sender and tx.origin
        address new_sender = address(1337);
        startHoax(new_sender, new_sender, type(uint256).max);

        // Expect Revert when session creation is not called from owner
        vm.expectRevert(abi.encodeWithSignature("RequireOwner(address,address)", new_sender, address(this)));
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 15, // allocationEnd,
            blockNumber + 20, // mintingStart,
            blockNumber + 25, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );
        vm.stopPrank();

        // Expect Revert when bad boundaries are input
        vm.expectRevert(abi.encodeWithSignature("BadSessionBounds(uint64,uint64,uint64,uint64)", blockNumber + 20, blockNumber + 10, blockNumber + 5, blockNumber + 5));
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 20, // allocationStart,
            blockNumber + 10, // allocationEnd,
            blockNumber + 5, // mintingStart,
            blockNumber + 5, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );

        // Expect Revert when bad boundaries are input
        vm.expectRevert(abi.encodeWithSignature("BadSessionBounds(uint64,uint64,uint64,uint64)", blockNumber + 10, blockNumber + 5, blockNumber + 20, blockNumber + 25));
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 5, // allocationEnd,
            blockNumber + 20, // mintingStart,
            blockNumber + 25, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );

        // Expect Revert when bad boundaries are input
        vm.expectRevert(abi.encodeWithSignature("BadSessionBounds(uint64,uint64,uint64,uint64)", blockNumber + 10, blockNumber + 15, blockNumber + 5, blockNumber + 25));
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 15, // allocationEnd,
            blockNumber + 5, // mintingStart,
            blockNumber + 25, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );

        // Expect Revert when bad boundaries are input
        vm.expectRevert(abi.encodeWithSignature("BadSessionBounds(uint64,uint64,uint64,uint64)", blockNumber + 10, blockNumber + 15, blockNumber + 20, blockNumber + 15));
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 15, // allocationEnd,
            blockNumber + 20, // mintingStart,
            blockNumber + 15, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );

        // Create a valid session
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 15, // allocationEnd,
            blockNumber + 20, // mintingStart,
            blockNumber + 25, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );
        TWAM.Session memory sess = twam.getSession(0);

        // Validate Session Parameters
        assert(sess.token == address(mockToken));
        assert(sess.coordinator == COORDINATOR);
        assert(sess.allocationStart == blockNumber + 10);
        assert(sess.allocationEnd == blockNumber + 15);
        assert(sess.mintingStart == blockNumber + 20);
        assert(sess.mintingEnd == blockNumber + 25);
        assert(sess.resultPrice == 0);
        assert(sess.minPrice == 100);
        assert(sess.depositToken == address(depositToken));
        assert(sess.depositAmount == 0);
        assert(sess.maxMintingAmount == TOKEN_SUPPLY);
        assert(sess.rolloverOption == 1);
    }

    /// @notice Tests rolling over a session
    function testRollover() public {
        uint64 blockNumber = SafeCastLib.safeCastTo64(block.number);

        // Expect Revert for an invalid sessionId
        vm.expectRevert(abi.encodeWithSignature("InvalidSession(uint256)", 0));
        twam.rollover(0);

        // Create a valid session
        twam.createSession(
            address(mockToken),
            COORDINATOR,
            blockNumber + 10, // allocationStart,
            blockNumber + 15, // allocationEnd,
            blockNumber + 20, // mintingStart,
            blockNumber + 25, // mintingEnd,
            100, // minPrice,
            address(depositToken),
            TOKEN_SUPPLY, // maxMintingAmount,
            1 // rolloverOption
        );

        // Expect Revert when not called from the coordinator context
        vm.expectRevert(abi.encodeWithSignature("InvalidCoordinator(address,address)", address(this), COORDINATOR));
        twam.rollover(0);

        // Hoax from the COORDINATOR context
        startHoax(COORDINATOR, COORDINATOR, type(uint256).max);

        // Expect Revert when the mint isn't over
        vm.expectRevert(abi.encodeWithSignature("MintingNotOver(uint256,uint64)", blockNumber, blockNumber + 25));
        twam.rollover(0);

        vm.warp(block.timestamp + 1000);

        // The rollover should succeed now that the minting period is over
        twam.rollover(0);

        vm.stopPrank();
    }

}
