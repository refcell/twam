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

    /// @notice testing suite precursors
    function setUp() public {
        /// @dev sets address(this) as the owner of the TWAM contract
        twam = new TWAM();
    }

    /// @notice test creating a twam session
    function testCreateSession() public {
        twam.createSession();
    }
}
