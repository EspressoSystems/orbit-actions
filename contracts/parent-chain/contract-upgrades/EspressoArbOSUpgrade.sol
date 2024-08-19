// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "../../child-chain/arbos-upgrade/UpgradeArbOSVersionAtTimestampAction.sol";

contract EspressoArbOSUpgrade is UpgradeArbOSVersionAtTimestampAction, Script   {
    constructor()
        UpgradeArbOSVersionAtTimestampAction(
            35,
            uint64(vm.envUint("UPGRADE_TIMESTAMP"))
        )
        {}
}