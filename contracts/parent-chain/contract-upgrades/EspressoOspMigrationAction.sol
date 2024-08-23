// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "@arbitrum/nitro-contracts/src/challenge/IChallengeManager.sol";
import "@arbitrum/nitro-contracts/src/rollup/IRollupCore.sol";
import "@arbitrum/nitro-contracts/src/rollup/IRollupAdmin.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract OspMigrationAction{ 

    error IncorrectWasmModuleRoot(bytes32 incorrectAddr);

    error AddressIsNotContract(address incorrectAddr);

    error ChallengeManagerUpdated(address newChallengeManagerAddr);

    error OspNotUpgraded(address oldOspAddress);

    error WasmModuleRootNotUpdated(bytes32 oldWasmModuleRoot);

    address public immutable newOspEntry;
    bytes32 public immutable newWasmModuleRoot;
    bytes32 public immutable currentWasmModuleRoot;
    address public immutable currentOspEntry;
    address public immutable rollup;
    address public immutable proxyAdmin;


    constructor(
        address _newOspEntry,
        bytes32 _newWasmModuleRoot,
        address _currentOspEntry,
        bytes32 _currentWasmModuleRoot,
        address _rollup,
        address _proxyAdmin
    ){
        if(_newWasmModuleRoot == bytes32(0)){
            revert IncorrectWasmModuleRoot(_newWasmModuleRoot);
        }

        if(_currentWasmModuleRoot == bytes32(0)){
            revert IncorrectWasmModuleRoot(_currentWasmModuleRoot);
        }

        if(!Address.isContract(_newOspEntry)){
            revert AddressIsNotContract(_newOspEntry);
        }

        if(!Address.isContract(_currentOspEntry)){
            revert AddressIsNotContract(_currentOspEntry);
        }

        if(!Address.isContract(_proxyAdmin)){
            revert AddressIsNotContract(_proxyAdmin);
        }

        if(!Address.isContract(_rollup)){
            revert AddressIsNotContract(_rollup);
        }
        newOspEntry = _newOspEntry;
        newWasmModuleRoot = _newWasmModuleRoot;
        currentOspEntry = _currentOspEntry;
        currentWasmModuleRoot = _currentWasmModuleRoot;
        rollup = _rollup;
        proxyAdmin = _proxyAdmin;
    }

    function perform() external{
        //Handle assertions in the perform function as we shouldn't be storing local state for delegated calls.
        
        // set the new challenge manager impl
        TransparentUpgradeableProxy challengeManager =
            TransparentUpgradeableProxy(payable(address(IRollupCore(rollup).challengeManager())));
        address chalManImpl = ProxyAdmin(proxyAdmin).getProxyImplementation(challengeManager);
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            challengeManager,
            chalManImpl, // Use the rollups current challenge manager as we only need to upgrade the OSP
            abi.encodeWithSelector(IChallengeManager.postUpgradeInit.selector, IOneStepProofEntry(newOspEntry), currentWasmModuleRoot, IOneStepProofEntry(currentOspEntry))
        );
        address postUpgradeChalManAddr = ProxyAdmin(proxyAdmin).getProxyImplementation(challengeManager);

        if(postUpgradeChalManAddr != chalManImpl){
            revert ChallengeManagerUpdated(postUpgradeChalManAddr);
        }
        IOneStepProofEntry newOsp = IChallengeManager(address(challengeManager)).osp();

        if(newOsp != IOneStepProofEntry(newOspEntry) ){
            revert OspNotUpgraded(address(newOsp));
        }
        
        IRollupAdmin(rollup).setWasmModuleRoot(newWasmModuleRoot);

        bytes32 postUpgradeWasmModuleRoot = IRollupCore(rollup).wasmModuleRoot();

        if(postUpgradeWasmModuleRoot != newWasmModuleRoot){
            revert WasmModuleRootNotUpdated(postUpgradeWasmModuleRoot);
        }
    }
}

contract EspressoOspMigrationAction is OspMigrationAction, Script{
    constructor()
        OspMigrationAction(
            address(0xBD110dAd17e1d4e6A629407474c9Ea4bbdEFa338),
            bytes32(0x2422802a7cda99737209430b103689205bc8e56eab8b08c6ad409e65e45c3145),
            address(0x9C2eD9F57D053FDfAEcBF1B6Dfd7C97e2e340B84),
            bytes32(0xbc1026ff45c20ea97e9e6057224a5668ea78d8f885c9b14fc849238e8ef5c5dc),
            address(0x0DFDF1473B14D2330A40F6a42bb6d601DD121E6b),
            address(0x2A1f38c9097e7883570e0b02BFBE6869Cc25d8a3)
        )
        {}
}