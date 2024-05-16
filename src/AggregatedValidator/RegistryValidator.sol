// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.23;

import { ERC7579ValidatorBase } from "@rhinestone/modulekit/src/Modules.sol";
import { PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";

import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

import {
    PackedUserOperation,
    _packValidationData as _packValidationData4337,
    ValidationData
} from "@rhinestone/modulekit/src/external/ERC4337.sol";
import { IERC7579Validator } from "@rhinestone/modulekit/src/external/ERC7579.sol";

uint256 constant TYPE_VALIDATOR = 1;

contract RegistryValidator is IERC7579Validator {
    address private immutable REGISTRY;

    constructor(address _registry) {
        REGISTRY = _registry;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        virtual
        override
        returns (uint256)
    {
        return _packValidationData4337(ValidationData(REGISTRY, 0, 0));
    }

    function isValidSignatureWithSender(
        address sender,
        bytes32 hash,
        bytes calldata data
    )
        external
        view
        virtual
        override
        returns (bytes4)
    { }

    /**
     * @dev This function is called by the smart account during installation of the module
     * @param data arbitrary data that may be required on the module during `onInstall`
     * initialization
     *
     * MUST revert on error (i.e. if module is already enabled)
     */
    function onInstall(bytes calldata data) external { }

    /**
     * @dev This function is called by the smart account during uninstallation of the module
     * @param data arbitrary data that may be required on the module during `onUninstall`
     * de-initialization
     *
     * MUST revert on error
     */
    function onUninstall(bytes calldata data) external { }

    /**
     * @dev Returns boolean value if module is a certain type
     * @param typeID the module type ID according the ERC-7579 spec
     *
     * MUST return true if the module is of the given type and false otherwise
     */
    function isModuleType(uint256 typeID) external view returns (bool) {
        if (typeID == TYPE_VALIDATOR) {
            return true;
        }
    }

    /**
     * @dev Returns if the module was already initialized for a provided smartaccount
     */
    function isInitialized(address smartAccount) external view returns (bool) { }
}
