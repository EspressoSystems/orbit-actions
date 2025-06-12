// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import {DeploymentHelpersScript} from "../../../../scripts/foundry/helper/DeploymentHelpers.s.sol";
import "nitro-contracts/bridge/SequencerInbox.sol";
import "nitro-contracts/bridge/ISequencerInbox.sol";

/// @notice This contract deploys and initializes a sequencerInbox contract that orbit chains can migrate to that enables compatibility
/// with the espresso confirmation layer
/// @dev BATCH_POSTER_ADDRS should be a comma delimited list that includes addresses. This list will give batch posting affordances to those addresses
///        For chains using the Espresso TEE integration, this will be the address of your new batch poster, if you decide to change it.
contract Deploy2Point1Point3EspressoSequencerInbox is DeploymentHelpersScript {
    function run() external {
        // Grab addresses from env
        address reader4844Addr = vm.envAddress("READER_ADDRESS");

        // Grab any uints we need to initialize the contract from envAddress
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 maxDataSize = vm.envUint("MAX_DATA_SIZE");
        // Grab booleans we need from env
        bool isUsingFeeToken = vm.envBool("IS_USING_FEE_TOKEN");
        bool isTargetChainArbitrum = vm.envBool("IS_TARGET_CHAIN_ARBITRUM");
        // if the target chain is arbitrum prank the vm so that simulation will match on chain result
        if (isTargetChainArbitrum) {
            bytes memory code = vm.getDeployedCode("ArbSysMock.sol:ArbSysMock");
            vm.etch(0x0000000000000000000000000000000000000064, code);
        }
        vm.startBroadcast(deployerPrivateKey);
        IReader4844 reader = IReader4844(reader4844Addr);
        // deploy new SequencerInbox contract from v2.1.3
        address newErc20SeqInboxImpl = deployBytecodeWithConstructorFromJSON(
            "/migration/espresso-2.1.3/SequencerInbox.sol/SequencerInbox.json", abi.encode(maxDataSize, reader, isUsingFeeToken)
        );
        vm.stopBroadcast();
    }
}
