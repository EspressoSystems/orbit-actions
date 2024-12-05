# Migrating your orbit chain to be compatible with the Espresso network.

This guide is intended for orbit chain operators that want to migrate their orbit chain to be compatible with the Espresso network.
It will provide step by step instructions that will walk you through the migration process

### Table of contents:
    1. Pre-requisites
    2. Contract deployments
        2a.Parent chain deployments
        2b.Child chain deployments
    3. Contract execution
        3a. Parent chain execution
        3b. Child chain execution

## 1. Pre-requisites

Before starting the migration process, it is important to gather some information that will be necessary for the coming steps.

The following information is necessary for the migration: 
    
    - V3_QUOTE_VERIFIER_ADDRESS: The address of a deployed automata v3 quote verifier contract.

    - MR_ENCLAVE: the MR_ENCLAVE value from the TEE.

    - MR_SIGNER: the MR_SIGNER data from the TEE.

    - PARENT_CHAIN_ID: The chain id of the parent chain that has your rollup contracts.

    - CHILD_CHAIN_CHAIN_NAME: The chain id for your orbit chain.
    
    - PARENT_CHAIN_RPC_URL: The RPC URL for the parent chain that has your rollup contracts.
    
    - CHILD_CHAIN_RPC_URL: The RPC URL for your orbit chain.

    - PARENT_CHAIN_UPGRADE_EXECUTOR_ADDRESS: The address of the upgrade executor for your rollup on the parent chain.

    - CHILD_CHAIN_UPGRADE_EXECUTOR_ADDRESS: The address of the upgrade executor for your rollup on the child chain.

    - ROLLUP_ADDRESS: The address of proxy contract managing the rollup logic for your orbit chain.
    
    - PROXY_ADMIN_ADDRESS: The address of the proxy admin for your rollup on the parent chain.

    - UPGRADE_TIMESTAMP: The unix timestamp you wish to perform the ArbOS upgrade at.
    
    - READER_ADDRESS: The address of a 4844 blob reader contract. This is relevant if the parent chain in your deployment    is not an arbitrum chain. If it is an arbitrum chain, this can be set to the zero address.

    - IS_USING_FEE_TOKEN: A boolean representing if this chaing is using a fee token, This is important for constructing    the sequencer inbox, and shouldn't be deviated from your current deployment.

    - MAX_DATA_SIZE: The max data size for batches accepted by the sequencer inbox. This should be set to the same
    values that currently exist as the MAX_DATA_SIZE in your sequencer inbox contract.

    - OLD_BATCH_POSTER_ADDRESS: The address used by the old batch poster. This can be the same as the new batch poster 
    address, If it is different, this is used to remove batch posting permissions from the previous batch poster.
    
    - NEW_BATCH_POSTER_ADDRESS: The address to use for the new batch poster. This will give batch posting permissions 
    in the sequencer inbox to the address stored in this env var.
    
    - BATCH_POSTER_MANAGER_ADDRESS: The address of the batch poster manager, if your deployment has one.
    If you wish to leave this unchanged from your previous batch poster manager, this should be set to the zero address.

We would reccommend that you aggregate these in a .env file in variables of the same names to the ones in .example-env so that you can export them when running the commands presented in future sections of this guide.

#### A note on Upgrade Executors

This migration presumes there to be upgrade executor contracts that are chain/rollup owners on both the parent chain, as well as the child chain. If you do not have an upgrade executor on the child chain, the contract execution commands at the end of this guide will not work.

#### A note on our deployment scripts:

The sequencer inbox contract being deploy in our scripts makes use of an Arbitrum precompile during it's construction. Because of this forge is unable to properly simulate the creation of the contract.
This leads to forge seeing a revert in the scripts execution that would not occur on network. To get around this we have included a ArbSysMock contract that we use to placate the unskippable simulation in forge. This will have no impact on on chain execution, but is included for the convenience of the user performing the migration. We also include the `--skip-simulation` flag in the forge script commands to avoid a second simulation that will not be satisfied with our mock contract. Rest assured these contracts will execute correctly on chain. 

## 2. Contract Deployments

### Parent chain deployments

The parent chain is where most of the contract deployments will happen for the migration to espresso. There are two forge scripts that you need to deploy on the parent chain. These scripts are located in the following directories:

[orbit-actions/contracts/parent-chain/espresso-migration/DeployAndInitEspressoSequencerInbox.s.sol](../contracts/parent-chain/espresso-migration/DeployAndInitEspressoSequencerInbox.s.sol)

and

[orbit-action/contracts/parent-chain/espresso-migration/DeployEspressoSequencerMigrationAction.s.sol](../contracts/parent-chain/espresso-migration/DeployEspressoSequencerMigrationAction.s.sol)

In addition to these forge scripts, you will need to use the deployEspressoTEEVerifier.ts script located in our fork of nitro contracts. This script is used to deploy our TEE verifier contract that will be used to verify the attestation quote produced from the execution environment that is running the espresso integrated batch poster.

These must ***MUST*** be deployed in the following order:
1. deployEspressoTEEVerifier.ts
2. DeployAndInitEspressoSequencerInbox.s.sol
3. DeployEspressoSequencerMigrationAction.s.sol

The following commands, when run from the orbit-actions repo, will run the three deployment scripts.

**IMPORTANT NOTE:**
    These commands will depend on certain environment variables being populated. If you havent already make sure to source the env file with all of the pre-requisite information.

The deployEspressoTEEVerifier.ts script can be run with the following command from the nitro-contracts repo with the celestia-integration branch checked out.

```
yarn hardhat run scripts/deployEspressoTEEVerifier.ts --network targetParentNetwork
```

Between the first and second deployment, you need to record the address of the newly deployed EspressoTEEVerifier contract and export it in the env var `ESPRESSO_TEE_VERIFIER_ADDRESS`.

#### DeployAndInitEspressoSequencerInbox.s.sol

```
forge script --chain $PARENT_CHAIN_CHAIN_ID contracts/parent-chain/espresso-migration/DeployAndInitEspressoSequencerInbox.s.sol:DeployAndInitEspressoSequencerInbox --rpc-url $PARENT_CHAIN_RPC_URL --broadcast -vvvv --skip-simulation
```

In a similar manner, you will need to record the sequencer inbox address in the env var `NEW_SEQUENCER_INBOX_IMPL_ADDRESS` after the second step during the migration.

To obtain this address from the deployment file generated by forge, you can run this command:

```
cat broadcast/DeployAndInitEspressoSequencerInbox.s.sol/$PARENT_CHAIN_ID/run-latest.json | jq -r '.transactions[0].contractAddress | cast to-checksum'
``` 

#### DeployEspressoSequencerMigrationAction.s.sol

```
forge script --chain $PARENT_CHAIN_CHAIN_ID contracts/parent-chain/espresso-migration/DeployEspressoSequencerMigrationAction.s.sol:DeployEspressoSequencerMigrationAction --rpc-url $PARENT_CHAIN_RPC_URL --broadcast -vvvv --skip-simulation

```

Similarly to the SequencerInbox implementation deployment, you should record the address at which the SequencerInbox migration action is deployed into the env var `SEQUENCER_MIGRATION_ACTION`

### Child chain deployments

There is only one forge script to run for deployments on the child chain, DeployArbOSUpgradeAction.s.sol. This script lives in the following location:

```
orbit-actions/contracts/child-chain/espresso-migration/DeployArbOSUpgradeAction.s.sol
```

You can deploy this contract to the child chain with the following command:

```
forge script --chain $CHILD_CHAIN_CHAIN_NAME contracts/child-chain/espresso-migration/DeployArbOSUpgradeAction.s.sol:DeployArbOSUpgradeAction  --rpc-url $CHILD_CHAIN_RPC_URL --broadcast -vvvv

```
You should store the address of the newly deployed upgrade action in the env var `ARBOS_UPGRADE_ACTION`

## 3. Contract execution

Two of the contracts deployed in the previous steps require additional steps to execute them on the parent a child chains for your rollup. 

### Parent chain contract execution

On the parent chain you need to call the `perform()` function on the EspressoOspMigrationAction contract with the following command:

```
cast send $PARENT_CHAIN_UPGRADE_EXECUTOR "execute(address, bytes)" $SEQUENCER_MIGRATION_ACTION $(cast calldata "perform()") --rpc-url $PARENT_CHAIN_RPC_URL --private-key $PRIVATE_KEY
```

### Child chain contract execution

On the parent chain you need to call the `perform()` function on the EspressoArbOSUpgrade contract with the following command:

```
cast send $CHILD_CHAIN_UPGRADE_EXECUTOR_ADDRESS "execute(address, bytes)" $ARBOS_UPGRADE_ACTION $(cast calldata "perform()") --rpc-url $CHILD_CHAIN_RPC_URL --private-key $PRIVATE_KEY
```

## Enabling Espresso batch poster behavior

To enable the behavior in the batch poster that provides compatibility with the Espresso network, you must send a request (via cast) to the `ArbOwner` precompile to update your networks chain config.

There is an example chain config json file in the same directory as this README to show which fields need to be added to the standard Arbitrum chain config.

Ensure that values other than the new EspressoTEEVerifierAddress are the same values as they are in your current chain config
It is **incredibly important** that the node with espresso compatible code is loaded with a chain config that contains the `EspressoTEEVerifierAddress` field inside the arbitrum chain parameters set to the zero address. If the config doesn't contain this flag, attempting to set the chain config in the following manner will cause the delegated call from the `UpgradeExecutor` to revert.

The request to the ArbOwner precompile must come from an address designated as a chain owner. Typically this is the `UpgradeExecutor`.

The following command uses cast and the `UpgradeExecutor` to send the new chain config to the network.

Note: The address 0x0000000000000000000000000000000000000070 is the hard-coded address of the ArbOwner precompile on arbitrum derived chains.


```
cast send $CHILD_CHAIN_UPGRADE_EXECUTOR_ADDRESS "executeCall(address, bytes)" 0x0000000000000000000000000000000000000070 $(cast calldata "setChainConfig(string)" "$(cat /chain/config/location)") --rpc-url $CHILD_CHAIN_RPC_URL --private-key $PRIVATE_KEY
```

