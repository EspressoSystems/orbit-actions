// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "@arbitrum/nitro-contracts/src/challenge/IChallengeManager.sol";
import "@arbitrum/nitro-contracts/src/challenge/ChallengeManager.sol";
import "@arbitrum/nitro-contracts/src/osp/OneStepProver0.sol";
import "@arbitrum/nitro-contracts/src/osp/OneStepProverMemory.sol";
import "@arbitrum/nitro-contracts/src/osp/OneStepProverMath.sol";
import "@arbitrum/nitro-contracts/src/osp/OneStepProverHostIo.sol";
import "@arbitrum/nitro-contracts/src/osp/OneStepProofEntry.sol";
import "@arbitrum/nitro-contracts/src/mocks/UpgradeExecutorMock.sol";
import "@arbitrum/nitro-contracts/src/rollup/RollupCore.sol";
import "@arbitrum/nitro-contracts/src/rollup/RollupCreator.sol";
import "@arbitrum/nitro-contracts/src/rollup/RollupAdminLogic.sol";
import "@arbitrum/nitro-contracts/src/rollup/RollupUserLogic.sol";
import "@arbitrum/nitro-contracts/src/rollup/ValidatorUtils.sol";
import "@arbitrum/nitro-contracts/src/rollup/ValidatorWalletCreator.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../parent-chain/espresso-migration/EspressoOspMigrationAction.sol";

contract EspressoOspMigrationAction is OspMigrationAction, Script {
    constructor()
        OspMigrationAction(
            address(0xBD110dAd17e1d4e6A629407474c9Ea4bbdEFa338),
            bytes32(0x2422802a7cda99737209430b103689205bc8e56eab8b08c6ad409e65e45c3145),
            address(0x9C2eD9F57D053FDfAEcBF1B6Dfd7C97e2e340B84),
            bytes32(0xbc1026ff45c20ea97e9e6057224a5668ea78d8f885c9b14fc849238e8ef5c5dc),
            address(0x3cf538A94538a25ee3bcA0287aB530ACCf9Dbaf6),
            address(0x2A1f38c9097e7883570e0b02BFBE6869Cc25d8a3)
        )
    {}
}

contract MockHotShot {
    mapping(uint256 => uint256) public commitments;

    function setCommitment(uint256 height, uint256 commitment) external {
        commitments[height] = commitment;
    }
}

contract MigrationTest is Test {
    RollupCreator public rollupCreator; // save the rollup creators address for bindings in the test.
    address public rollupAddress; // save the rollup address for bindings in the test.
    address public rollupOwner = makeAddr("rollupOwner");
    address public deployer = makeAddr("deployer");
    IRollupAdmin public rollupAdmin;
    IRollupUser public rollupUser;
    DeployHelper public deployHelper;
    IReader4844 dummyReader4844 = IReader4844(address(137));
    MockHotShot public hotshot = new MockHotShot();
    IUpgradeExecutor upgradeExecutor;

    IOneStepProofEntry originalOspEntry;
    IOneStepProofEntry newOspEntry = IOneStepProofEntry(
        new OneStepProofEntry(
            new OneStepProver0(), new OneStepProverMemory(), new OneStepProverMath(), new OneStepProverHostIo()
        )
    );

    uint256 public constant MAX_FEE_PER_GAS = 1_000_000_000;
    uint256 public constant MAX_DATA_SIZE = 117_964;

    BridgeCreator.BridgeContracts public ethBasedTemplates = BridgeCreator.BridgeContracts({
        bridge: new Bridge(),
        sequencerInbox: new SequencerInbox(MAX_DATA_SIZE, dummyReader4844, false),
        inbox: new Inbox(MAX_DATA_SIZE),
        rollupEventInbox: new RollupEventInbox(),
        outbox: new Outbox()
    });
    BridgeCreator.BridgeContracts public erc20BasedTemplates = BridgeCreator.BridgeContracts({
        bridge: new ERC20Bridge(),
        sequencerInbox: new SequencerInbox(MAX_DATA_SIZE, dummyReader4844, true),
        inbox: new ERC20Inbox(MAX_DATA_SIZE),
        rollupEventInbox: new ERC20RollupEventInbox(),
        outbox: new ERC20Outbox()
    });

    /* solhint-disable func-name-mixedcase */
    //create items needed for a rollup and deploy it. This code is lovingly borrowed from the rollupcreator.t.sol foundry test.
    function setUp() public {
        //// deploy rollup creator and set templates
        vm.startPrank(deployer);
        rollupCreator = new RollupCreator();
        deployHelper = new DeployHelper();

        for (uint256 i = 1; i < 10; i++) {
            hotshot.setCommitment(uint256(i), uint256(i));
        }

        // deploy BridgeCreators
        BridgeCreator bridgeCreator = new BridgeCreator(ethBasedTemplates, erc20BasedTemplates);

        IUpgradeExecutor upgradeExecutorLogic = new UpgradeExecutorMock();
        upgradeExecutor = upgradeExecutorLogic;

        (
            IOneStepProofEntry ospEntry,
            IChallengeManager challengeManager,
            IRollupAdmin _rollupAdmin,
            IRollupUser _rollupUser
        ) = _prepareRollupDeployment();

        originalOspEntry = ospEntry;

        rollupAdmin = _rollupAdmin;
        rollupUser = _rollupUser;

        //// deploy creator and set logic
        rollupCreator.setTemplates(
            bridgeCreator,
            ospEntry,
            challengeManager,
            _rollupAdmin,
            _rollupUser,
            upgradeExecutorLogic,
            address(new ValidatorUtils()),
            address(new ValidatorWalletCreator()),
            deployHelper
        );

        // deployment params
        ISequencerInbox.MaxTimeVariation memory timeVars =
            ISequencerInbox.MaxTimeVariation(((60 * 60 * 24) / 15), 12, 60 * 60 * 24, 60 * 60);
        Config memory config = Config({
            confirmPeriodBlocks: 20,
            extraChallengeTimeBlocks: 200,
            stakeToken: address(0),
            baseStake: 1000,
            wasmModuleRoot: keccak256("wasm"),
            owner: rollupOwner,
            loserStakeEscrow: address(200),
            chainId: 1337,
            chainConfig: "abc",
            genesisBlockNum: 15_000_000,
            sequencerInboxMaxTimeVariation: timeVars
        });

        // prepare funds
        uint256 factoryDeploymentFunds = 1 ether;
        vm.deal(deployer, factoryDeploymentFunds);

        /// deploy rollup
        address[] memory batchPosters = new address[](1);
        batchPosters[0] = makeAddr("batch poster 1");
        address batchPosterManager = makeAddr("batch poster manager");
        address[] memory validators = new address[](2);
        validators[0] = makeAddr("validator1");
        validators[1] = makeAddr("validator2");

        RollupCreator.RollupDeploymentParams memory deployParams = RollupCreator.RollupDeploymentParams({
            config: config,
            batchPosters: batchPosters,
            validators: validators,
            maxDataSize: MAX_DATA_SIZE,
            nativeToken: address(0),
            deployFactoriesToL2: true,
            maxFeePerGasForRetryables: MAX_FEE_PER_GAS,
            batchPosterManager: batchPosterManager
        });
        rollupAddress = rollupCreator.createRollup{value: factoryDeploymentFunds}(deployParams);

        vm.stopPrank();
    }

    function _prepareRollupDeployment()
        internal
        returns (
            IOneStepProofEntry ospEntry,
            IChallengeManager challengeManager,
            IRollupAdmin rollupAdminLogic,
            IRollupUser rollupUserLogic
        )
    {
        //// deploy challenge stuff
        ospEntry = new OneStepProofEntry(
            new OneStepProver0(), new OneStepProverMemory(), new OneStepProverMath(), new OneStepProverHostIo()
        );
        challengeManager = new ChallengeManager();

        //// deploy rollup logic
        rollupAdminLogic = IRollupAdmin(new RollupAdminLogic());
        rollupUserLogic = IRollupUser(new RollupUserLogic());

        return (ospEntry, challengeManager, rollupAdminLogic, rollupUserLogic);
    }

    function _getProxyAdmin(address proxy) internal view returns (address) {
        bytes32 adminSlot = bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
        return address(uint160(uint256(vm.load(proxy, adminSlot))));
    }

    function test_migrateToEspresso() public {
        //begin by seting pre-requisites in the vm so the test can get the data it needs.
        IRollupCore rollup = IRollupCore(rollupAddress);

        address upgradeExecutorExpectedAddress = computeCreateAddress(address(rollupCreator), 4);
        //ensure we have the correct address for the proxy admin
        assertEq(
            ProxyAdmin(_getProxyAdmin(address(rollup.sequencerInbox()))).owner(),
            upgradeExecutorExpectedAddress,
            "Invalid proxyAdmin's owner"
        );

        IUpgradeExecutor _upgradeExecutor = IUpgradeExecutor(upgradeExecutorExpectedAddress);

        vm.setEnv("NEW_OSP_ENTRY", Strings.toHexString(uint256(uint160(address(newOspEntry)))));
        vm.setEnv("CURRENT_OSP_ENTRY", Strings.toHexString(uint256(uint160(address(originalOspEntry)))));
        vm.setEnv("ROLLUP_ADDRESS", Strings.toHexString(uint256(uint160(address(rollupAddress)))));
        vm.setEnv("PROXY_ADMIN", Strings.toHexString(uint256(uint160(computeCreateAddress(address(rollupCreator), 1)))));
        vm.setEnv("NEW_WASM_MODULE_ROOT", Strings.toHexString(uint256(keccak256("newRoot"))));
        vm.setEnv("CURRENT_WASM_MODULE_ROOT", Strings.toHexString(uint256(keccak256("wasm"))));
        bytes memory data = abi.encodeWithSelector(OspMigrationAction.perform.selector);

        address migration = address(new EspressoOspMigrationAction());

        vm.prank(rollupOwner);
        _upgradeExecutor.execute(migration, data);
        vm.stopPrank();

        assertEq(
            address(rollup.challengeManager().getOsp(bytes32(uint256(keccak256("wasm"))))),
            address(originalOspEntry),
            "CondOsp at original root is not what was expected."
        );
        assertEq(
            address(rollup.challengeManager().getOsp(bytes32(uint256(keccak256("newRoot"))))),
            address(newOspEntry),
            "CondOsp at new root is not what was expected."
        );
        assertEq(
            rollup.wasmModuleRoot(),
            bytes32(uint256(keccak256("newRoot"))),
            "Rollup's wasmModuleRoot was not changed by migration"
        );
    }
}
