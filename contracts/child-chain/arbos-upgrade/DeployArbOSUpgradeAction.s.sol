// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "./EspressoArbOSUpgrade.sol";

contract DeployArbOSUpgradeAction is Script{
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");  
        uint64 upgradeTimestamp = uint64(vm.envUint("UPGRADE_TIMESTAMP"));      
        vm.startBroadcast(deployerPrivateKey);
        EspressoArbOSUpgrade arbOSUpgrade = new EspressoArbOSUpgrade(
            upgradeTimestamp
        );
        vm.stopBroadcast();
    }
}