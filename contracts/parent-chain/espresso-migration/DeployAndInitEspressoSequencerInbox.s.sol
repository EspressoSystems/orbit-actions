// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "nitro-contracts/bridge/SequencerInbox.sol";
import "nitro-contracts/bridge/ISequencerInbox.sol";


contract DeployAndInitEspressoSequencerInbox is Script {
    function run() external {
        // Grab addresses from env
        address bridgeAddr = vm.envAddress("BRIDGE_ADDRESS");
        address reader4844Addr = vm.envAddress("READER_ADDRESS");
        address espressoTeeVerifierAddr = vm.envAddress("ESPRESSO_TEE_VERIFIER_ADDRESS");
     
        // Grab the list of batch poster addresses valid for this rollup. This is a comma delimited list of addresses.
        address[] memory batchPosters = vm.envAddress("BATCH_POSTER_ADDRS", ",");
        address batchPosterManager = vm.envAddress("BATCH_POSTER_MANAGER");

        // Grab any uints we need to initialize the contract from envAddress
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 delayBlocks = vm.envUint("DELAY_BLOCKS");
        uint256 futureBlocks = vm.envUint("FUTURE_BLOCKS"); 
        uint256 delaySeconds = vm.envUint("DELAY_SECONDS");
        uint256 futureSeconds = vm.envUint("FUTURE_SECONDS");
        uint256 maxDataSize = vm.envUint("MAX_DATA_SIZE");
        // Grab booleans we need from env
        bool isUsingFeeToken = vm.envBool("IS_USING_FEE_TOKEN");

        // initialize interfaces needed
        IReader4844 reader = IReader4844(reader4844Addr);
        IBridge bridge = IBridge(bridgeAddr);
        // Start broadcast to deploy and initializer the sequencerInbox
        vm.startBroadcast(deployerPrivateKey);
        SequencerInbox sequencerInbox = new SequencerInbox(maxDataSize, reader, isUsingFeeToken);
        ISequencerInbox.MaxTimeVariation memory maxTimeVariation = ISequencerInbox.MaxTimeVariation({
         delayBlocks: delayBlocks,
         futureBlocks: futureBlocks,
         delaySeconds: delaySeconds,
         futureSeconds: futureSeconds
        });
        sequencerInbox.initialize(bridge, maxTimeVariation, espressoTeeVerifierAddr);
        // Setting batch posters and batch poster manager
        for (uint256 i = 0; i < batchPosters.length; i++) {
            sequencerInbox.setIsBatchPoster(batchPosters[i], true);
        }
        if (batchPosterManager != address(0)) {
            sequencerInbox.setBatchPosterManager(batchPosterManager);
        }
        vm.stopBroadcast();
    }
}
