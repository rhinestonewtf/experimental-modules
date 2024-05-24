// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Test } from "forge-std/Test.sol";
import {
    RhinestoneModuleKit,
    ModuleKitHelpers,
    ModuleKitUserOp,
    AccountInstance
} from "modulekit/ModuleKit.sol";
import { MODULE_TYPE_HOOK } from "modulekit/external/ERC7579.sol";
import { SpendingLimitHook } from "src/SpendingLimitHook/SpendingLimitHook.sol";
import { MockERC20 } from "solmate/test/utils/mocks/MockERC20.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract SpendingLimitHookTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // account and modules
    AccountInstance internal instance;
    SpendingLimitHook internal hook;
    MockERC20 internal token;

    // internal variables
    bool checkBalance = true;

    function setUp() public {
        init();

        // Create the hook
        hook = new SpendingLimitHook();
        vm.label(address(hook), "SpendingLimitHook");

        // Create the token
        token = new MockERC20("USDC", "USDC", 6);
        vm.label(address(token), "Token");

        // Create the account
        instance = makeAccountInstance("SpendingLimitHook");
        vm.deal(address(instance.account), 10 ether);
        token.mint(address(instance.account), 10 ether);

        // Create the spending limit
        SpendingLimitHook.TokenConfig[] memory configs = new SpendingLimitHook.TokenConfig[](1);
        configs[0] = SpendingLimitHook.TokenConfig({ token: address(token), limit: 1 ether });

        // Install the module
        instance.installModule({
            moduleTypeId: MODULE_TYPE_HOOK,
            module: address(hook),
            data: abi.encode(configs)
        });
    }

    function testExec() public {
        // Create a target address and send some ether to it
        address target = makeAddr("target");
        uint256 value = 1 ether;

        // Get the current balance of the target
        uint256 prevBalance = token.balanceOf(target);

        // Execute the call
        instance.exec({
            target: address(token),
            value: 0,
            callData: abi.encodeWithSelector(IERC20.transfer.selector, target, value)
        });

        if (checkBalance) {
            // Check if the balance of the target has increased
            assertEq(token.balanceOf(target), prevBalance + value);
        }
    }

    function testExec_RevertWhen_LimitReached() public {
        // Execute transfer
        testExec();

        // Execute transfer again but expect a revert
        checkBalance = false;

        instance.expect4337Revert();
        testExec();
    }

    function testExec_MultiplePeriods() public {
        // Set time to 0
        vm.warp(0);
        // Execute transfer
        testExec();

        // Set time to 1 week
        vm.warp(1 weeks);
        // Execute transfer in new period
        testExec();
    }

    function testExec_CalculateGas() public {
        // Calculate gas
        instance.log4337Gas("spendingLimitHook");

        // Execute transfer
        testExec();
    }
}
