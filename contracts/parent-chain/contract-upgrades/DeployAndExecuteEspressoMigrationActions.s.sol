// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "./EspressoArbOSUpgrade.sol";
import "./EspressoOspMigrationAction.sol";

contract DeployAndExecuteEspressoMigrationActions is Script{
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        EspressoArbOSUpgrade arbOSUpgrade = new EspressoArbOSUpgrade();
        EspressoOspMigrationAction ospMigrationAction = new EspressoOspMigrationAction();
        arbOSUpgrade.perform();
        ospMigrationAction.perform();
        vm.stopBroadcast();
    }
}