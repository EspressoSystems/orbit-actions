// Copyright 2021-2022, Offchain Labs, Inc.
// For license information, see https://github.com/nitro/blob/master/LICENSE
// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.0;

contract ArbSysMock {
    function arbOSVersion() external pure returns (uint256) {
        return 1;
    }
}
