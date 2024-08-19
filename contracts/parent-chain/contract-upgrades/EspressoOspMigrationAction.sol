// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "forge-std/Script.sol";
import "@arbitrum/nitro-contracts/src/challenge/IChallengeManager.sol";
import "@arbitrum/nitro-contracts/src/rollup/IRollupCore.sol";
import "@arbitrum/nitro-contracts/src/rollup/IRollupAdmin.sol";

import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/utils/Address.sol";

error IncorrectWasmModuleRoot(bytes32 incorrectAddr);

error AddressIsNotContract(address incorrectAddr);

error ChallengeManagerUpdated(address newChallengeManagerAddr);

error OspNotUpgraded(address oldOspAddress);

error WasmModuleRootNotUpdated(bytes32 oldWasmModuleRoot);



contract OspMigrationAction{ 
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
        newOspEntry = _newOspEntry;
        newWasmModuleRoot = _newWasmModuleRoot;
        currentOspEntry = _currentOspEntry;
        currentWasmModuleRoot = _currentWasmModuleRoot;
        rollup = _rollup;
        proxyAdmin = _proxyAdmin;
    }

    function perform() external{
        //Handle assertions in the perform functoin as we shouldn't be storing local state for delegated calls.
        if(newWasmModuleRoot == bytes32(0)){
            revert IncorrectWasmModuleRoot(newWasmModuleRoot);
        }

        if(currentWasmModuleRoot == bytes32(0)){
            revert IncorrectWasmModuleRoot(currentWasmModuleRoot);
        }

        if(Address.isContract(newOspEntry) == false){
            revert AddressIsNotContract(newOspEntry);
        }

        if(Address.isContract(currentOspEntry) == false){
            revert AddressIsNotContract(currentOspEntry);
        }

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
            address(vm.envAddress("NEW_OSP_ENTRY")),
            bytes32(vm.envBytes32("NEW_WASM_MODULE_ROOT")),
            address(vm.envAddress("CURRENT_OSP_ENTRY")),
            bytes32(vm.envBytes32("CURRENT_WASM_MODULE_ROOT")),
            address(vm.envAddress("ROLLUP_ADDRESS")),
            address(vm.envAddress("PROXY_ADMIN"))
        )
        {}
}