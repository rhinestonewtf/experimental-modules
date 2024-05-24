// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { FrameVerifier, MessageData } from "frame-verifier/FrameVerifier.sol";
import { MessageType } from "frame-verifier/Encoder.sol";

contract FrameValidator is ERC7579ValidatorBase {
    mapping(address => uint64) public smartAccountFID;

    function onInstall(bytes calldata data) external override {
        (uint64 fid) = abi.decode(data, (uint64));
        smartAccountFID[msg.sender] = fid;
    }

    function onUninstall(bytes calldata) external override {
        delete smartAccountFID[msg.sender];
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return smartAccountFID[smartAccount] != 0;
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        (
            bytes32 public_key,
            bytes32 signature_r,
            bytes32 signature_s,
            MessageData memory messageData
        ) = abi.decode(userOp.signature, (bytes32, bytes32, bytes32, MessageData));

        if (
            messageData.fid != smartAccountFID[userOp.sender]
                || messageData.type_ != MessageType.MESSAGE_TYPE_FRAME_ACTION
        ) {
            return _packValidationData(true, 0, 0);
        }
        bool isValidSignature =
            FrameVerifier.verifyMessageData(public_key, signature_r, signature_s, messageData);
        return _packValidationData(!isValidSignature, 0, 0);
    }

    function isValidSignatureWithSender(
        address,
        bytes32,
        bytes calldata
    )
        external
        view
        virtual
        override
        returns (bytes4)
    {
        return EIP1271_FAILED;
    }

    function name() external pure returns (string memory) {
        return "FrameValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
