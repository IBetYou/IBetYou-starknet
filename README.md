## Requirements
- Node.js v12.22.4
- npm/npx v7.21.1
- Docker v20.10.8
- Cairo 0.5.1

## Install Dependencies
```
npm install
```

## Use
Make sure docker is running locally

Generate the artifacts by compiling the contract using staknet-compile:
### `starknet-compile`
```
npx hardhat starknet-compile 
```
### `starknet-deploy`
```
npx hardhat starknet-deploy --starknet-network starknetLocalhost
```

## Test
To test Starknet contracts with Mocha, use the regular Hardhat `test` task:
```
npx hardhat test
```
## Deploying and interacting using starknet CLI

### Compile
```
mkdir build

starknet-compile contracts/contract.cairo \
    --output build/contract_compiled.json \
    --abi build/contract_abi.json
```
This will generate the contract address and transaction hash
Export the contract address for easy access. Copy the contract address from the output.
```
export CONTRACT_ADDRESS=0x0324c875882a9b93f6dc01ef6216bac5efdbf8f00c71e7f4c7e09c884cc1b97f
```
We can also export network name
```
export STARKNET_NETWORK=alpha
```

Add balance to user 1 and user 2
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function increase_balance  --input 1 1000
```
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function increase_balance  --input 2 1000
```

View balance of user 1 and user 2

```
starknet call --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function get_balance --input 1
```
```
starknet call --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function get_balance --input 2
```
### Create a bet by user 1
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function create_bet \
    --inputs 1 100 100981
```

### User 2 joins the  bet as antibetter
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function join_counter_better \
    --inputs 2
```

### User 3 joins the bet as judge

```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function join_judge \
    --inputs 3
```

### Judge (user 3) votes user 1 as winner

```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi contract_abi.json \
    --function vote_better \
    --inputs 3 1
```

Now, after the transaction is verified, verify the balance of user 1, it should get increased by 2x of the bet amount