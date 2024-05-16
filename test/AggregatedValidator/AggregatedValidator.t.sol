// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@rhinestone/modulekit/src/ModuleKit.sol";
import { IEntryPoint, PackedUserOperation } from "@rhinestone/modulekit/src/external/ERC4337.sol";
import "@rhinestone/modulekit/src/Helpers.sol";
import "@ERC4337/account-abstraction/contracts/interfaces/IAggregator.sol";
import "forge-std/Test.sol";
import "@rhinestone/modulekit/src/Core.sol";
import "@rhinestone/registry/src/Registry.sol";
import "@rhinestone/registry/src/DataTypes.sol";
import "@rhinestone/modulekit/src/Mocks.sol";
import "src/AggregatedValidator/RegistryValidator.sol";
import "./mocks/MockResolver.sol";
import "./mocks/MockSchemaValidator.sol";
import "./mocks/MockERC1271Attester.sol";
import "./mocks/MockModule.sol";
import { MODULE_TYPE_VALIDATOR } from "@rhinestone/modulekit/src/external/ERC7579.sol";

contract AggregatedValidator is RhinestoneModuleKit, Test {
    using ModuleKitHelpers for *;
    using ModuleKitUserOp for *;

    MockERC20 internal token;
    AccountInstance internal instance;
    MockResolver resolverTrue;
    MockSchemaValidator schemaValidatorTrue;
    ResolverUID internal defaultResolverUID;
    SchemaUID defaultSchemaUID;

    Registry registry;
    RegistryValidator validator;

    address moduleDev;
    address attester1;
    address attester2;
    string defaultSchema = "Foobar";

    function setUp() public {
        moduleDev = makeAddr("moduleDev");
        attester1 = makeAddr("attester1");
        attester2 = makeAddr("attester2");
        instance = makeAccountInstance("account");
        registry = new Registry();
        validator = new RegistryValidator(address(registry));
        instance.installModule({
            moduleTypeId: MODULE_TYPE_VALIDATOR,
            module: address(validator),
            data: ""
        });

        token = new MockERC20();
        token.initialize("Mock Token", "MTK", 18);
        deal(address(token), instance.account, 100 ether);
        vm.deal(instance.account, 10 ether);
        setUp_registry();
    }

    function setUp_registry() public {
        resolverTrue = new MockResolver(true);
        schemaValidatorTrue = new MockSchemaValidator(true);
        defaultResolverUID = registry.registerResolver(IExternalResolver(address(resolverTrue)));
        defaultSchemaUID = registry.registerSchema(
            defaultSchema, IExternalSchemaValidator(address(schemaValidatorTrue))
        );

        vm.prank(moduleDev);
        registry.registerModule(defaultResolverUID, address(validator), "");

        address[] memory attesters = new address[](1);
        attesters[0] = attester1;
        vm.prank(instance.account);
        registry.trustAttesters(1, attesters);

        ModuleType[] memory typesEnc = new ModuleType[](1);
        typesEnc[0] = ModuleType.wrap(1);
        AttestationRequest memory request = AttestationRequest({
            moduleAddr: address(validator),
            expirationTime: type(uint48).max,
            data: "",
            moduleTypes: typesEnc
        });
        vm.prank(attester1);
        registry.attest(defaultSchemaUID, request);
    }

    function test_aggregate() public {
        UserOpData memory userOpData = instance.getExecOps({
            target: address(token),
            value: 0,
            callData: abi.encodeCall(MockERC20.transfer, (makeAddr("recipient"), 10 ether)),
            txValidator: address(validator)
        });

        PackedUserOperation[] memory userOps = new PackedUserOperation[](1);
        userOps[0] = userOpData.userOp;

        IEntryPoint.UserOpsPerAggregator[] memory aggOps = new IEntryPoint.UserOpsPerAggregator[](1);

        aggOps[0] = IEntryPoint.UserOpsPerAggregator({
            userOps: userOps,
            aggregator: IAggregator(address(registry)),
            signature: ""
        });
        instance.aux.entrypoint.handleAggregatedOps(aggOps, payable(address(0x123)));
    }
}
