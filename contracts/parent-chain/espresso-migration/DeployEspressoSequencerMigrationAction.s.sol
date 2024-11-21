// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "./EspressoSequencerInboxMigrationAction.sol";

/// @notice This contract deploys and initializes a sequencerInbox contract that orbit chains can migrate to that enables compatibility
/// with the espresso confirmation layer
/// @dev BATCH_POSTER_ADDRS should be a comma delimited list that includes addresses. This list will give batch posting affordances to those addresses
///        For chains using the Espresso TEE integration, this will be the address of your new batch poster, if you decide to change it.
contract DeployEspressoSequencerMigrationAction is Script {
    function run() external {
        // Grab addresses from env
        address rollupAddr = vm.envAddress("ROLLUP_ADDRESS");
        address newSequencerInboxImplAddr = vm.envAddress("NEW_SEQUENCER_INBOX_IMPL_ADDRESS");
        address proxyAdminAddr = vm.envAddress("PROXY_ADMIN_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        EspressoSequencerInboxMigrationAction migrationAction =
            new EspressoSequencerInboxMigrationAction(newSequencerInboxImplAddr, rollupAddr, proxyAdminAddr);
        vm.stopBroadcast();
    }
}
