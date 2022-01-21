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

contract TwamFactoryTest is DSTestPlus, stdCheats {

    /// @dev Use forge-std Vm logic
    Vm public constant vm = Vm(HEVM_ADDRESS);

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
        for(uint256 i = 1; i < TOKEN_SUPPLY; i++) {
            mockToken.mint(address(twamFactory), i);
        }
        // Save the first token to transfer to set the permissioned session creator
        // mockToken.mint(COORDINATOR, 0);
        // mockToken.transfer(address(twamFactory), 0);
    }

    /// @notice Creates a Twam from Factory
    function testCreateTwam() public {
      uint64 t = SafeCastLib.safeCastTo64(block.timestamp);

      // We should expect a NotApproved revert
      vm.expectRevert(abi.encodeWithSignature(
        "NotApproved(address,address,address)",
        address(this),
        address(0),
        address(mockToken)
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