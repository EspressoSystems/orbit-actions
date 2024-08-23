// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "./EspressoOspMigrationAction.sol";

contract DeployEspressoOspMigrationAction is Script{
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        EspressoOspMigrationAction migrationAction = new EspressoOspMigrationAction();
        vm.startBroadcast(deployerPrivateKey);
    }
}