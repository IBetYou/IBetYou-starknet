## Requirements
- Node.js v12.22.4
- npm/npx v7.21.1
- Docker v20.10.8
- Cairo 0.6.0

## Install Dependencies
```
npm install
```


###The "crypto" folder from the following git repository has to be manually added in the lib/ folder on the project root
```
https://github.com/starkware-libs/starkex-resources
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
    --abi build/contract_abi.json \
    --function increase_balance  --input $BETTOR_PUBLIC_KEY 1000 \
    --signature $BETTER_SIGN_PART_1 $BETTER_SIGN_PART_2
```
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function increase_balance  --input $COUNTER_BETTOR_PUBLIC_KEY 1000 \
    --signature $COUNTER_BETTER_SIGN_PART_1 $COUNTER_BETTER_SIGN_PART_2
```

View balance of user 1 and user 2

```
starknet call --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function get_balance --input $BETTOR_PUBLIC_KEY
```
```
starknet call --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function get_balance --input $COUNTER_BETTOR_PUBLIC_KEY
```
### Create a bet
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function createBet \
    --inputs $BETTOR_PUBLIC_KEY $AMOUNT $BET_TEXT
    --signature $BETTER_SIGN_BETAMOUNT_PART_1 $BETTER_SIGN_BETAMOUNT_PART_2
```

### User 2 joins the  bet as counterbettor
```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function joinCounterBettor \
    --inputs $COUNTER_BETTOR_PUBLIC_KEY
```

### User 3 joins the bet as judge

```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function joinJudge \
    --inputs $JUDGE_PUBLIC_KEY
```

### Judge (user 3) votes user 1 as winner

```
starknet invoke \
    --address $CONTRACT_ADDRESS \
    --abi build/contract_abi.json \
    --function voteBettor \
    --inputs $JUDGE_PUBLIC_KEY $BETTOR_PUBLIC_KEY
    --signature $JUDGE_SIGN_PART_1 $JUDGE_SIGN_PART_2
```

Now, after the transaction is verified, verify the balance of user 1, it should get increased by 2x of the bet amount