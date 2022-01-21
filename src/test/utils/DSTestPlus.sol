// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

// forge-std imports
import {Vm} from "@std/Vm.sol";
import {stdCheats, stdError} from "@std/stdlib.sol";

// solmate Imports
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DSTestPlus as DSTest} from "@solmate/test/utils/DSTestPlus.sol";

contract DSTestPlus is DSTest, stdCheats {

    /// @dev Use forge-std Vm logic
    Vm public constant vm = Vm(HEVM_ADDRESS);

    /// @dev Compares ERC20 Tokens
    function assertERC20Eq(ERC20 erc1, ERC20 erc2) internal {
        assertEq(address(erc1), address(erc2));
    }
}