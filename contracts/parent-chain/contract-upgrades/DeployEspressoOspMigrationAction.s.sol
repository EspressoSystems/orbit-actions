// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "./EspressoOspMigrationAction.sol";

contract DeployEspressoOspMigrationAction is Script{
    function run() external{
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address newOspEntry = vm.envAddress("NEW_OSP_ENTRY");
        bytes32 newWasmModuleRoot = vm.envBytes32("NEW_WASM_MODULE_ROOT");
        address currentOspEntry = vm.envAddress("CURRENT_OSP_ENTRY");
        bytes32 currentWasmModuleRoot = vm.envBytes32("CURRENT_WASM_MODULE_ROOT");
        address rollup = vm.envAddress("ROLLUP_ADDRESS");
        address proxyAdmin = vm.envAddress("PROXY_ADMIN");

        vm.startBroadcast(deployerPrivateKey);
        OspMigrationAction migrationAction = new OspMigrationAction(
            newOspEntry,
            newWasmModuleRoot,
            currentOspEntry,
            currentWasmModuleRoot,
            rollup,
            proxyAdmin
        );
        vm.stopBroadcast();
    }
}
