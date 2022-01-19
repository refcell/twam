// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import {DSTestPlus} from "./utils/DSTestPlus.sol";
import {stdCheats, stdError} from "forge-std/stdlib.sol";
import {Vm} from "forge-std/Vm.sol";

import {TWAM} from "../TWAM.sol";

contract TWAMTest is DSTestPlus {

    /// @dev Use forge-std Vm logic
    Vm public constant vm = Vm(HEVM_ADDRESS);

    /// @dev The TWAM Contract
    TWAM public twam;

    /// @notice VB is the one true coordinatooor
    address public constant COORDINATOR = 0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B;

    /// @notice testing suite precursors
    function setUp() public {
        /// @dev sets address(this) as the owner of the TWAM contract
        twam = new TWAM();
        assert(twam.owner() == address(this));
    }

    ////////////////////////////////////////////////////
    ///           SESSION MANAGEMENT LOGIC           ///
    ////////////////////////////////////////////////////

    /// @notice test creating a twam session
    function testCreateSession(
        address token,
        uint64 allocationStart,
        uint64 allocationEnd,
        uint64 mintingStart,
        uint64 mintingEnd,
        uint256 minPrice,
        address depositToken,
        uint256 maxMintingAmount,
        uint256 rolloverOption
    ) public {
        if (token == address(0)) token = address(1337);
        twam.createSession(
            token, COORDINATOR, allocationStart, allocationEnd,
            mintingStart, mintingEnd, minPrice, depositToken,
            maxMintingAmount, rolloverOption
        );
    }
}
