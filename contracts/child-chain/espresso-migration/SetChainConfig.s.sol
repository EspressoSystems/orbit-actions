// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "nitro-contracts/bridge/SequencerInbox.sol";
import "nitro-contracts/bridge/ISequencerInbox.sol";
import {IUpgradeExecutor} from "@offchainlabs/upgrade-executor/src/IUpgradeExecutor.sol";
import "nitro-contracts/precompiles/ArbOwner.sol";

/// @notice This contract deploys and initializes a sequencerInbox contract that orbit chains can migrate to that enables compatibility
/// with the espresso confirmation layer
/// @dev BATCH_POSTER_ADDRS should be a comma delimited list that includes addresses. This list will give batch posting affordances to those addresses
///        For chains using the Espresso TEE integration, this will be the address of your new batch poster, if you decide to change it.
contract SetEspressoChainConfig is Script {
    function run() external {
        // Grab addresses from env
        address childChainUpgradeExecutorAddr = vm.envAddress("CHILD_CHAIN_UPGRADE_EXECUTOR_ADDRESS");
        address arbOwnerAddr = address(0x070);
        address espressoTeeVerifierAddr = vm.envAddress("ESPRESSO_TEE_VERIFIER_ADDRESS");
        string memory chainConfig = vm.envString("CHAIN_CONFIG");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
       
        IUpgradeExecutor upgradeExecutor = IUpgradeExecutor(childChainUpgradeExecutorAddr);
        // Start broadcast to deploy and initializer the SequencerInbox
        vm.startBroadcast(deployerPrivateKey);
        bytes memory setChainConfigParams = abi.encodeCall(ArbOwner.setChainConfig, chainConfig);
        upgradeExecutor.executeCall(arbOwnerAddr, setChainConfigParams);
        vm.stopBroadcast();
    }
}
