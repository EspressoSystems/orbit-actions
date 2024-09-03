// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "forge-std/Script.sol";
import "./UpgradeArbOSVersionAtTimestampAction.sol";

contract EspressoArbOSUpgrade is UpgradeArbOSVersionAtTimestampAction, Script   {
    constructor(
        uint64 upgradeTimestamp
    )
        UpgradeArbOSVersionAtTimestampAction(
            35,
            upgradeTimestamp
        )
        {}
}