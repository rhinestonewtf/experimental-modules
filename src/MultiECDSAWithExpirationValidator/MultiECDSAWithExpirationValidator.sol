// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

import { ERC7579ValidatorBase } from "modulekit/Modules.sol";
import { PackedUserOperation } from "modulekit/external/ERC4337.sol";
import { FrameVerifier, MessageData } from "frame-verifier/FrameVerifier.sol";
import { MessageType } from "frame-verifier/Encoder.sol";
import { SignatureCheckerLib } from "solady/utils/SignatureCheckerLib.sol";
import { ECDSA } from "solady/utils/ECDSA.sol";

contract MultiECDSAWithExpirationValidator is ERC7579ValidatorBase {
    using SignatureCheckerLib for address;

    struct Session {
        uint48 expirationTimestamp;
        address key;
    }

    mapping(uint256 => mapping(address => Session)) public sessionKey;
    mapping(address => uint256) internal sessionKeys;

    function onInstall(bytes calldata data) external override {
        (uint48 expirationTimestamp, address key) = abi.decode(data, (uint48, address));
        sessionKey[0][msg.sender] = Session({ expirationTimestamp: expirationTimestamp, key: key });
        sessionKeys[msg.sender] = 1;
    }

    function onUninstall(bytes calldata) external override {
        uint256 count = sessionKeys[msg.sender];
        for (uint256 i = 1; i <= count; i++) {
            delete sessionKey[i][msg.sender];
        }
        sessionKeys[msg.sender] = 0;
    }

    function isInitialized(address smartAccount) external view returns (bool) {
        return sessionKeys[smartAccount] != 0;
    }

    function addSessionKey(uint48 expirationTimestamp, address key) external {
        uint256 count = sessionKeys[msg.sender];
        sessionKey[count][msg.sender] =
            Session({ expirationTimestamp: expirationTimestamp, key: key });
        sessionKeys[msg.sender] = count + 1;
    }

    function removeSessionKey(uint256 keyId) external {
        delete sessionKey[keyId][msg.sender];
    }

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    )
        external
        override
        returns (ValidationData)
    {
        (uint256 keyId, bytes memory signature) = abi.decode(userOp.signature, (uint256, bytes));
        Session memory session = sessionKey[keyId][userOp.sender];
        bool validSig =
            session.key.isValidSignatureNow(ECDSA.toEthSignedMessageHash(userOpHash), signature);
        return _packValidationData(!validSig, session.expirationTimestamp, 0);
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
        return "MultiECDSAWithExpirationValidator";
    }

    function version() external pure returns (string memory) {
        return "0.0.1";
    }

    function isModuleType(uint256 typeID) external pure override returns (bool) {
        return typeID == TYPE_VALIDATOR;
    }
}
