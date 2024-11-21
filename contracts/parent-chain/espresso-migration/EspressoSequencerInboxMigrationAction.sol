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
/// @dev _newSequencerInboxImpl: This is the address of the SequencerInbox implementation to point rollup's upgradeable proxy to.
/// @dev _rollup: the address of the rollup to be migrated to the new SequencerInbox
/// @dev _proxyAdminAddr: the address of the proxyAdmin for the rollup being migrated to the new SequencerInbox
///      enable espresso confirmations at the end of the migration
/// @dev    Modified from
///         https://github.com/ArbitrumFoundation/governance/blob/a5375eea133e1b88df2116ed510ab2e3c07293d3/src/gov-action-contracts/AIPs/ArbOS20/ArbOS20Action.sol
contract EspressoSequencerInboxMigrationAction {
    address public immutable newSequencerInboxImpl;
    address public immutable rollup;
    address public immutable proxyAdminAddr;

    error AddressIsNotContract(address incorrectAddr);

    error MaxTimeVariationNotSet();

    error SequencerInboxNotUpgraded(address oldSequencerInboxAddr);

    constructor(address _newSequencerInboxImpl, address _rollup, address _proxyAdminAddr) {
        // If the new impl addresses are contracts, we need to revert
        if (!Address.isContract(_newSequencerInboxImpl)) {
            revert AddressIsNotContract(_newSequencerInboxImpl);
        }

        if (!Address.isContract(_rollup)) {
            revert AddressIsNotContract(_rollup);
        }

        if (!Address.isContract(_proxyAdminAddr)) {
            revert AddressIsNotContract(_proxyAdminAddr);
        }

        newSequencerInboxImpl = _newSequencerInboxImpl;

        rollup = _rollup;

        proxyAdminAddr = _proxyAdminAddr;
    }

    function perform() public {
        // set up contracts we need to interact with.
        IRollupCore rollupCore = IRollupCore(rollup);
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);
        TransparentUpgradeableProxy sequencerInbox =
            TransparentUpgradeableProxy(payable(address(rollupCore.sequencerInbox())));
        // Get future blocks value to create assertion at end of migration
        (, uint256 futureBlocksBefore,,) = ISequencerInbox(address(sequencerInbox)).maxTimeVariation();
        // migrate the rollup to the new sequencer inbox
        proxyAdmin.upgrade(sequencerInbox, newSequencerInboxImpl);

        address proxyImpl = proxyAdmin.getProxyImplementation(sequencerInbox);
        // if the proxy implementation hasn't been updated, we need to revert.
        if (proxyImpl != newSequencerInboxImpl) {
            revert SequencerInboxNotUpgraded(proxyImpl);
        }

        (, uint256 futureBlocksAfter,,) = ISequencerInbox(address(sequencerInbox)).maxTimeVariation();

        // if the max time variation was not set, the sequencer inbox is not initialized, we need to revert.
        if (futureBlocksBefore == 0 || futureBlocksBefore != futureBlocksAfter) {
            revert MaxTimeVariationNotSet();
        }
    }
}
