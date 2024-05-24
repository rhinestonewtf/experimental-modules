// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { ERC7579HookDestruct } from "modulekit/Modules.sol";
import { Execution } from "modulekit/external/ERC7579.sol";
import { IERC20 } from "forge-std/interfaces/IERC20.sol";

contract SpendingLimitHook is ERC7579HookDestruct {
    /*//////////////////////////////////////////////////////////////////////////
                                     STORAGE
    //////////////////////////////////////////////////////////////////////////*/

    struct SpendingLimit {
        uint256 limit;
        mapping(uint256 timeperiod => uint256) spent;
    }

    struct TokenConfig {
        address token;
        uint256 limit;
    }

    mapping(address account => mapping(address token => SpendingLimit)) public spendingLimits;
    mapping(address account => address[]) tokens;

    /*//////////////////////////////////////////////////////////////////////////
                                     CONFIG
    //////////////////////////////////////////////////////////////////////////*/

    /* Initialize the module with the given data
     * @param data The data to initialize the module with
     */
    function onInstall(bytes calldata data) external override {
        (TokenConfig[] memory configs) = abi.decode(data, (TokenConfig[]));
        for (uint256 i = 0; i < configs.length; i++) {
            spendingLimits[msg.sender][configs[i].token].limit = configs[i].limit;
            tokens[msg.sender].push(configs[i].token);
        }
    }

    /* De-initialize the module with the given data
     * @param data The data to de-initialize the module with
     */
    function onUninstall(bytes calldata) external override {
        for (uint256 i = 0; i < tokens[msg.sender].length; i++) {
            delete spendingLimits[msg.sender][tokens[msg.sender][i]];
        }
        delete tokens[msg.sender];
    }

    /*
     * Check if the module is initialized
     * @param smartAccount The smart account to check
     * @return true if the module is initialized, false otherwise
     */
    function isInitialized(address smartAccount) external view returns (bool) {
        return tokens[smartAccount].length > 0;
    }

    function setSpendingLimits(TokenConfig[] calldata configs) external {
        for (uint256 i = 0; i < configs.length; i++) {
            spendingLimits[msg.sender][configs[i].token].limit = configs[i].limit;
            tokens[msg.sender].push(configs[i].token);
        }
    }

    function removeSpendingLimit(address token) external {
        delete spendingLimits[msg.sender][token];
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     MODULE LOGIC
    //////////////////////////////////////////////////////////////////////////*/

    function _checkSpendingLimit(address target, bytes calldata callData) internal {
        if (callData.length >= 4) {
            if (bytes4(callData[:4]) == IERC20.transfer.selector) {
                // Get the spending limit
                SpendingLimit storage config = spendingLimits[msg.sender][target];
                uint256 timeperiod = block.timestamp / 1 weeks;
                if (config.limit != 0) {
                    (, uint256 value) = abi.decode(callData[4:], (address, uint256));
                    if (config.spent[timeperiod] + value > config.limit) {
                        revert("SpendingLimitHook: spending limit exceeded");
                    } else {
                        config.spent[timeperiod] += value;
                    }
                }
            }
        }
    }

    function onExecute(
        address account,
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _checkSpendingLimit(target, callData);
    }

    function onExecuteBatch(
        address account,
        address msgSender,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        for (uint256 i = 0; i < executions.length; i++) {
            _checkSpendingLimit(executions[i].target, executions[i].callData);
        }
    }

    function onExecuteFromExecutor(
        address account,
        address msgSender,
        address target,
        uint256 value,
        bytes calldata callData
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        _checkSpendingLimit(target, callData);
    }

    function onExecuteBatchFromExecutor(
        address account,
        address msgSender,
        Execution[] calldata executions
    )
        internal
        virtual
        override
        returns (bytes memory hookData)
    {
        for (uint256 i = 0; i < executions.length; i++) {
            _checkSpendingLimit(executions[i].target, executions[i].callData);
        }
    }

    /*//////////////////////////////////////////////////////////////////////////
                                     METADATA
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * The name of the module
     * @return name The name of the module
     */
    function name() external pure returns (string memory) {
        return "SpendingLimitHook";
    }

    /**
     * The version of the module
     * @return version The version of the module
     */
    function version() external pure returns (string memory) {
        return "1.0.0";
    }

    /* 
        * Check if the module is of a certain type
        * @param typeID The type ID to check
        * @return true if the module is of the given type, false otherwise
        */
    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_HOOK;
    }
}
