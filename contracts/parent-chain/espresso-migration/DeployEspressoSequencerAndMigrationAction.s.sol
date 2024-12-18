// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import {DeploymentHelpersScript} from "../../../scripts/foundry/helper/DeploymentHelpers.s.sol";
import "./EspressoSequencerInboxMigrationAction.sol";

contract DeployEspressoSequencerAndMigrationAction is DeploymentHelpersScript {
  function run() public{
    // EspressoTEEVerifier related env vars 
    bytes32 mrEnclave = vm.envBytes32("MR_ENCLAVE");
    bytes32 mrSigner = vm.envBytes32("MR_SIGNER");
    address quoteVerifierAddr = vm.envAddress("V3_QUOTE_VERIFIER_ADDRESS");
    //Migration Action Env Vars
    address rollupAddr = vm.envAddress("ROLLUP_ADDRESS");
    address proxyAdminAddr = vm.envAddress("PROXY_ADMIN_ADDRESS");
    address espressoTeeVerifierAddr = vm.envAddress("ESPRESSO_TEE_VERIFIER_ADDRESS");
    address oldBatchPosterAddr = vm.envAddress("OLD_BATCH_POSTER_ADDRESS");
    address newBatchPosterAddr = vm.envAddress("NEW_BATCH_POSTER_ADDRESS");
    address batchPosterManagerAddr = vm.envAddress("BATCH_POSTER_MANAGER_ADDRESS");
    // SequencerInbox deployemnt env vars
    address reader4844Addr = vm.envAddress("READER_ADDRESS");
    uint256 maxDataSize = vm.envUint("MAX_DATA_SIZE");
    bool isUsingFeeToken = vm.envBool("IS_USING_FEE_TOKEN");
    // Other required env vars
    uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    // Trick the Vm into seeing that this opcode exists. This allows us to deploy to remote networks 
    bytes memory code = vm.getDeployedCode("ArbSysMock.sol:ArbSysMock");
    vm.etch(0x0000000000000000000000000000000000000064, code);
    // initialize interfaces needed
    IReader4844 reader = IReader4844(reader4844Addr);
    vm.startBroadcast(deployerPrivateKey);
    address espressoTEEVerifier = deployBytecodeWithConstructorFromJSON("nitro-contracts/build/contracts/src/bridge/EspressoTEEVerifier/EspressoTEEVerifier.json", abi.encode(mrEnclave, mrSigner, quoteVerifierAddr) );
    address sequencerInbox = deployBytecodeWithConstructorFromJSON("nitro-contracts/build/contracts/src/bridge/SequencerInbox/SequencerInbox.json", abi.encode(maxDataSize, reader, isUsingFeeToken));
    EspressoSequencerInboxMigrationAction migrationAction =
            new EspressoSequencerInboxMigrationAction(sequencerInbox, rollupAddr, proxyAdminAddr, espressoTEEVerifier, oldBatchPosterAddr, newBatchPosterAddr, batchPosterManagerAddr);
    vm.stopBroadcast();
  }
  
}
