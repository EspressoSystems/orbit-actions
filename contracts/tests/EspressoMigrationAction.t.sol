//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "nitro-contracts/challenge/IChallengeManager.sol";
import "nitro-contracts/challenge/ChallengeManager.sol";
import "nitro-contracts/osp/OneStepProver0.sol";
import "nitro-contracts/osp/OneStepProverMemory.sol";
import "nitro-contracts/osp/OneStepProverMath.sol";
import "nitro-contracts/osp/OneStepProverHostIo.sol";
import "nitro-contracts/osp/OneStepProofEntry.sol";
import "nitro-contracts/mocks/UpgradeExecutorMock.sol";
import "nitro-contracts/rollup/RollupCore.sol";
import "nitro-contracts/rollup/RollupCreator.sol";
import "nitro-contracts/rollup/RollupAdminLogic.sol";
import "nitro-contracts/rollup/RollupUserLogic.sol";
import "nitro-contracts/rollup/ValidatorUtils.sol";
import "nitro-contracts/rollup/ValidatorWalletCreator.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import "../parent-chain/espresso-migration/EspressoSequencerInboxMigrationAction.sol";
import {EspressoTEEVerifierMock} from "nitro-contracts/mocks/EspressoTEEVerifier.sol";

contract MigrationTest is Test {
    IReader4844 dummyReader4844 = IReader4844(address(137));
    address newSequencerImplAddress = address(new SequencerInbox(1000, dummyReader4844, true));
    address mockTEEVerifier = address(new EspressoTEEVerifierMock());
    address oldBatchPosterAddr = address(0x01112);
    address newBatchPosterAddr = address(0x01113);
    address batchPosterManagerAddr = address(0x01114);
    RollupCreator public rollupCreator; // save the rollup creators address for bindings in the test.
    address public rollupAddress; // save the rollup address for bindings in the test.
    address public proxyAdminAddr; // save the proxy admin addr for building contracts in the test.
    address public rollupOwner = makeAddr("rollupOwner");
    address public deployer = makeAddr("deployer");
    IRollupAdmin public rollupAdmin;
    IRollupUser public rollupUser;
    DeployHelper public deployHelper;

    IUpgradeExecutor upgradeExecutor;

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

        EspressoTEEVerifierMock espressoTEEVerifier = new EspressoTEEVerifierMock();

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
            sequencerInboxMaxTimeVariation: timeVars,
            espressoTEEVerifier: address(espressoTEEVerifier)
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
        ProxyAdmin admin = ProxyAdmin(_getProxyAdmin(address(rollup.sequencerInbox())));
        address adminAddr = _getProxyAdmin(address(rollup.sequencerInbox()));

        assertEq(admin.owner(), upgradeExecutorExpectedAddress, "Invalid proxyAdmin's owner");

        IUpgradeExecutor _upgradeExecutor = IUpgradeExecutor(upgradeExecutorExpectedAddress);

        bytes memory data = abi.encodeWithSelector(EspressoSequencerInboxMigrationAction.perform.selector);

        address migration = address(
            new EspressoSequencerInboxMigrationAction(
                newSequencerImplAddress,
                rollupAddress,
                adminAddr,
                mockTEEVerifier,
                oldBatchPosterAddr,
                newBatchPosterAddr,
                batchPosterManagerAddr,
                false
            )
        );

        vm.prank(rollupOwner);
        _upgradeExecutor.execute(migration, data);
        vm.stopPrank();
        assertEq(
            address(
                admin.getProxyImplementation(TransparentUpgradeableProxy(payable(address(rollup.sequencerInbox()))))
            ),
            address(newSequencerImplAddress),
            "Sequencer Inbox has not been updated"
        );
        SequencerInbox proxyInbox = SequencerInbox(address(rollup.sequencerInbox()));
        assertEq(mockTEEVerifier, address(proxyInbox.espressoTEEVerifier()));
    }
}
