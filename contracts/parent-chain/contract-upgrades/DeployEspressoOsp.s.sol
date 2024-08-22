// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "nitro-contracts.git/osp/OneStepProverMemory.sol";
import "nitro-contracts.git/osp/OneStepProverMath.sol";
import "nitro-contracts.git/osp/OneStepProverHostIo.sol";
import "nitro-contracts.git/osp/OneStepProver0.sol";
import "nitro-contracts.git/osp/OneStepProofEntry.sol";


contract DeployEspressoOsp is Script{
    function run() external{
        address hotshotAddr = vm.envAddress("HOTSHOT_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        OneStepProofEntry newOSP = new OneStepProofEntry(
            new OneStepProver0(),
            new OneStepProverMemory(),
            new OneStepProverMath(),
            new OneStepProverHostIo(hotshotAddr)
        );

        vm.stopBroadcast();
    }
}