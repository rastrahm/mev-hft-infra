// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {MevErrors} from "../../src/errors/MevErrors.sol";
import {RejectETH} from "../../src/mocks/RejectETH.sol";
import {CoinbaseTipHarness} from "../helpers/LibHarnesses.sol";

/**
 * @title CoinbaseTipTest
 * @notice Unit tests de tip a `block.coinbase` (Solidity call vs Yul).
 */
contract CoinbaseTipTest is Test {
    CoinbaseTipHarness internal harness;
    address internal builder;

    function setUp() public {
        harness = new CoinbaseTipHarness();
        builder = makeAddr("builder");
        vm.coinbase(builder);
        vm.deal(address(harness), 100 ether);
    }

    function test_pay_zeroIsNoop() public {
        uint256 beforeBal = builder.balance;
        harness.pay(0);
        assertEq(builder.balance, beforeBal);
        assertEq(address(harness).balance, 100 ether);
    }

    function test_pay_transfersToCoinbase() public {
        harness.pay(1 ether);
        assertEq(builder.balance, 1 ether);
        assertEq(address(harness).balance, 99 ether);
    }

    function test_payAssembly_transfersToCoinbase() public {
        harness.payAssembly(2 ether);
        assertEq(builder.balance, 2 ether);
        assertEq(address(harness).balance, 98 ether);
    }

    function test_pay_revertsWhenCoinbaseRejects() public {
        RejectETH rejector = new RejectETH();
        vm.coinbase(address(rejector));
        vm.expectRevert(MevErrors.TipTransferFailed.selector);
        harness.pay(1 ether);
    }

    function test_payAssembly_revertsWhenCoinbaseRejects() public {
        RejectETH rejector = new RejectETH();
        vm.coinbase(address(rejector));
        vm.expectRevert(MevErrors.TipTransferFailed.selector);
        harness.payAssembly(1 ether);
    }

    function testFuzz_pay(uint96 tipWei) public {
        tipWei = uint96(bound(tipWei, 0, 50 ether));
        uint256 beforeBuilder = builder.balance;
        uint256 beforeHarness = address(harness).balance;
        harness.pay(tipWei);
        assertEq(builder.balance, beforeBuilder + tipWei);
        assertEq(address(harness).balance, beforeHarness - tipWei);
    }

    function testFuzz_payAssembly(uint96 tipWei) public {
        tipWei = uint96(bound(tipWei, 0, 50 ether));
        uint256 beforeBuilder = builder.balance;
        uint256 beforeHarness = address(harness).balance;
        harness.payAssembly(tipWei);
        assertEq(builder.balance, beforeBuilder + tipWei);
        assertEq(address(harness).balance, beforeHarness - tipWei);
    }
}
