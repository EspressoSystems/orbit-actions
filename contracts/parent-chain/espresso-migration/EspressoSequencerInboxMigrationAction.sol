// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "nitro-contracts/bridge/ISequencerInbox.sol";
import "nitro-contracts/bridge/SequencerInbox.sol";
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
    address public immutable espressoTEEVerifier;
    address public immutable oldBatchPosterAddr;
    address public immutable newBatchPosterAddr;
    address public immutable batchPosterManager;

    error AddressIsNotContract(address incorrectAddr);

    error OldBatchPosterMustNotBeZeroAddr();

    error NewBatchPosterMustNotBeZeroAddr();
    
    error BatchPosterManagerMustNotBeZeroAddr();
    
    error MaxTimeVariationNotSet();

    error SequencerInboxNotUpgraded(address oldSequencerInboxAddr);
    
    error espressoTEEVerifierNotSet();

    constructor(address _newSequencerInboxImpl, address _rollup, address _proxyAdminAddr, address _espressoTEEVerifier, address _oldBatchPosterAddr, address _newBatchPosterAddr, address _batchPosterManager) {
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

        if (!Address.isContract(_espressoTEEVerifier)){
            revert AddressIsNotContract(_espressoTEEVerifier);
        }

        if (_oldBatchPosterAddr == address(0x0)){
            revert OldBatchPosterMustNotBeZeroAddr();
        }
        
        if (_newBatchPosterAddr == address(0x0)){
            revert NewBatchPosterMustNotBeZeroAddr();
        }

        if (_batchPosterManager == address(0x0)){
            revert BatchPosterManagerMustNotBeZeroAddr();
        }

        newSequencerInboxImpl = _newSequencerInboxImpl;

        rollup = _rollup;

        proxyAdminAddr = _proxyAdminAddr;

        espressoTEEVerifier = _espressoTEEVerifier;

        oldBatchPosterAddr = _oldBatchPosterAddr;

        newBatchPosterAddr = _newBatchPosterAddr;

        batchPosterManager = _batchPosterManager;
    
    }

    function perform() public {
        // set up contracts we need to interact with.
        IRollupCore rollupCore = IRollupCore(rollup);
        ProxyAdmin proxyAdmin = ProxyAdmin(proxyAdminAddr);

        TransparentUpgradeableProxy sequencerInbox =
            TransparentUpgradeableProxy(payable(address(rollupCore.sequencerInbox())));
        
        // migrate the rollup to the new sequencer inbox
        proxyAdmin.upgrade(sequencerInbox, newSequencerInboxImpl);

        address proxyImpl = proxyAdmin.getProxyImplementation(sequencerInbox);
        // if the proxy implementation hasn't been updated, we need to revert.
        if (proxyImpl != newSequencerInboxImpl) {
            revert SequencerInboxNotUpgraded(proxyImpl);
        }
       
        SequencerInbox proxyInbox = SequencerInbox(address(rollupCore.sequencerInbox()));
        // Set the TEE verifier address
        proxyInbox.setEspressoTEEVerifier(espressoTEEVerifier);
        // Remove the permissions for the old batch poster addresses
        proxyInbox.setIsBatchPoster(oldBatchPosterAddr, false);
        // Whitelist the new batch posters address to enable it to post batches 
        proxyInbox.setIsBatchPoster(newBatchPosterAddr, true);
        // Set the batch poster manager.
        proxyInbox.setBatchPosterManager(batchPosterManager);


        address proxyTEEVerifierAddr = address(proxyInbox.espressoTEEVerifier());
        if (proxyTEEVerifierAddr != espressoTEEVerifier) {
            revert espressoTEEVerifierNotSet(); 
        }
    }
}
