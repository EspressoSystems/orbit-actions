// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "nitro-contracts/bridge/ISequencerInbox.sol";
import "nitro-contracts/bridge/IBridge.sol";
import "nitro-contracts/bridge/IInbox.sol";
import "nitro-contracts/bridge/IOutbox.sol";
import "nitro-contracts/rollup/IRollupAdmin.sol";
import "nitro-contracts/rollup/IRollupLogic.sol";

/// @notice Upgrades an Arbitrum orbit chain to use a SequencerInbox contract compatible with Espresso
/// @dev    Modified from
///         https://github.com/ArbitrumFoundation/governance/blob/a5375eea133e1b88df2116ed510ab2e3c07293d3/src/gov-action-contracts/AIPs/ArbOS20/ArbOS20Action.sol
contract EspressoSequencerInboxMigrationAction {
    address public immutable newSequencerInboxImpl;

    constructor(address _newSequencerInboxImpl) {
        require(Address.isContract(_newSequencerInboxImpl), "_newSequencerInboxImpl is not a contract");
        newSequencerInboxImpl = _newSequencerInboxImpl;
    }

    function perform(IRollupCore rollup, ProxyAdmin proxyAdmin) public {
        TransparentUpgradeableProxy sequencerInbox =
            TransparentUpgradeableProxy(payable(address(rollup.sequencerInbox())));
        (, uint256 futureBlocksBefore,,) = ISequencerInbox(address(sequencerInbox)).maxTimeVariation();
        proxyAdmin.upgrade(sequencerInbox, newSequencerInboxImpl);

        // verify
        require(
            proxyAdmin.getProxyImplementation(sequencerInbox) == newSequencerInboxImpl,
            "new seq inbox implementation not set"
        );
        (, uint256 futureBlocksAfter,,) = ISequencerInbox(address(sequencerInbox)).maxTimeVariation();
        require(futureBlocksBefore != 0 && futureBlocksBefore == futureBlocksAfter, "maxTimeVariation not set");
    }
}
