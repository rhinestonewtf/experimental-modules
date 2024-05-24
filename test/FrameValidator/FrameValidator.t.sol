// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "modulekit/ModuleKit.sol";
import "modulekit/Modules.sol";
import "modulekit/Helpers.sol";
import "src/FrameValidator/FrameValidator.sol";
import "frame-verifier/Encoder.sol";
import { MODULE_TYPE_VALIDATOR } from "modulekit/external/ERC7579.sol";

contract FrameValidatorTest is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    // main account and dependencies
    AccountInstance internal instance;
    FrameValidator internal validator;

    uint64 fid;

    function setUp() public {
        init();

        fid = 64_417;

        validator = new FrameValidator();
        vm.label(address(validator), "FrameValidator");

        instance = makeAccountInstance("FrameValidator");
        vm.deal(address(instance.account), 10 ether);
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: abi.encode(fid)
        });
    }

    function getFrameData() internal returns (bytes memory sig) {
        MessageData memory md = MessageData({
            type_: MessageType.MESSAGE_TYPE_FRAME_ACTION,
            fid: fid,
            timestamp: 97_190_733,
            network: FarcasterNetwork.FARCASTER_NETWORK_TESTNET,
            frame_action_body: FrameActionBody({
                url: hex"68747470733a2f2f6578616d706c652e636f6d",
                button_index: 1,
                cast_id: CastId({ fid: fid, hash: hex"e9eca527e4d2043b1f77b5b4d847d4f71172116b" })
            })
        });
        assertEq(
            MessageDataCodec.encode(md),
            // result from hub monorepo
            hex"080d10a1f70318cd86ac2e20028201330a1368747470733a2f2f6578616d706c652e636f6d10011a1a08a1f7031214e9eca527e4d2043b1f77b5b4d847d4f71172116b"
        );

        // from hub mono repo
        bytes memory sigHex =
            hex"17bdafddf9cf7464959a28d57fb5da7c596de4796f663588ea24d804c13ca043f46a546ca474d1b4420cc48e8720d8051786b21a689cdf485f78e51e36a12b05";
        (bytes32 r, bytes32 s) = abi.decode(sigHex, (bytes32, bytes32));
        bytes32 pk = 0x292404752ddd67080bbfe93af4017e51388ebc3c9fb96b8984658155de590b38;

        sig = abi.encode(pk, r, s, md);
    }

    function testExec__Send() public {
        address target = makeAddr("target");
        uint256 value = 1 ether;
        uint256 prevBalance = target.balance;

        UserOpData memory userOpData = instance.getExecOps({
            target: target,
            value: value,
            callData: "",
            txValidator: address(validator)
        });
        bytes memory signature = getFrameData();
        userOpData.userOp.signature = signature;
        userOpData.execUserOps();

        assertEq(target.balance, prevBalance + value);
    }
}
