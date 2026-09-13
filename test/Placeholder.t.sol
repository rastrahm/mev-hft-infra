// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Placeholder} from "../src/Placeholder.sol";

/**
 * @title PlaceholderTest
 * @notice Smoke tests de Fase 0: compile, remappings forge-std/OZ, stub.
 */
contract PlaceholderTest is Test {
    Placeholder internal placeholder;

    function setUp() public {
        placeholder = new Placeholder();
    }

    function test_ping() public view {
        assertEq(placeholder.ping(), 15);
    }

    function test_pingConstant() public view {
        assertEq(placeholder.PING(), 15);
    }

    /// @dev Valida remapping `@openzeppelin/contracts/` sin desplegar token.
    function test_openzeppelinRemapping() public pure {
        assertTrue(type(IERC20).interfaceId != bytes4(0));
    }
}
