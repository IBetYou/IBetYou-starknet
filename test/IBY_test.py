import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract
from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign)
# The path to the contract source code.
# my change: modified the path to adapt to the file system
MASTER_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "..", "contracts", "Master.cairo")
BET_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "..", "contracts", "Bet.cairo")
ACCOUNT_CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "..", "contracts", "Account.cairo")


# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_bet():
    # Compile the contracts.
    master_contract_definition = compile_starknet_files(
        [MASTER_CONTRACT_FILE], debug_info=True)
    bet_contract_definition = compile_starknet_files(
        [BET_CONTRACT_FILE], debug_info=True)
    account_contract_definition = compile_starknet_files(
        [ACCOUNT_CONTRACT_FILE], debug_info=True)
    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contracts.
    master_contract = await starknet.deploy(
        source=MASTER_CONTRACT_FILE)
    bet_contract = await starknet.deploy(
        source=BET_CONTRACT_FILE)
    account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE)


    # Bettor private key
    bettor_private_key = 12345
    # Counter Bettor private key
    counter_bettor_private_key = 54321
    # Judge private key
    bettor_judge_private_key = 121212
    counter_bettor_judge_private_key = 121244
    bettor_public_key = private_to_stark_key(bettor_private_key)
    counter_bettor_public_key = private_to_stark_key(counter_bettor_private_key)
    bettor_judge_public_key = private_to_stark_key(bettor_judge_private_key)
    counter_bettor_judge_public_key = private_to_stark_key(counter_bettor_judge_private_key)


     # Amount variables
    balance_amount = 50
    bet_amount = 10

    await account_contract.add_balance(user_id=bettor_public_key, amount=balance_amount).invoke()
    await account_contract.add_balance(user_id=counter_bettor_public_key, amount=balance_amount).invoke()
    # Check the result of get_balance().
    execution_info=await account_contract.get_balance(user_id=bettor_public_key).call()
    bettor_balance= execution_info.result
    execution_info=await account_contract.get_balance(user_id=counter_bettor_public_key).call()
    counter_bettor_balance= execution_info.result

    assert bettor_balance == (balance_amount,)
    assert counter_bettor_balance == (balance_amount,)

    print(f'Balance of User 1: {bettor_balance.res}')
    print(f'Balance of User 2: {counter_bettor_balance.res}')

     # Create bet by bettor
    await master_contract.create_bet(user_id=bettor_public_key, amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    # Check if amount is deducted from user account
    execution_info=await account_contract.get_balance(user_id=bettor_public_key).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount-bet_amount,)
    print(f'Balance of User 1 after placing bet: {bettor_balance.res}')

    # Counter Bettor joins the bet
    await master_contract.join_counter_bettor(user_id=counter_bettor_public_key,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    # Check if amount is deducted from counter bettor account
    execution_info= await account_contract.get_balance(user_id=counter_bettor_public_key).call()
    counter_bettor_balance= execution_info.result
    assert counter_bettor_balance == (balance_amount-bet_amount,)
    print(f'Balance of User 2 after joining bet: {counter_bettor_balance.res}')

    #Bettor Judge joins the bet
    await master_contract.join_bettor_judge(user_id=bettor_judge_public_key,address=bet_contract.contract_address).invoke()
   
    #Counter Bettor Judge joins the bet
    await master_contract.join_counter_bettor_judge(user_id=counter_bettor_judge_public_key,address=bet_contract.contract_address).invoke()
    bet_status = await bet_contract.get_bet_status().call()
    bettor_judge = bet_status.result.bet.bettor_judge
    counter_bettor_judge = bet_status.result.bet.counter_bettor_judge
    assert bettor_judge == bettor_judge_public_key
    assert counter_bettor_judge == counter_bettor_judge_public_key
    # Judges vote for user 1
    await master_contract.bettor_judge_vote(user_id=bettor_public_key,address=bet_contract.contract_address).invoke()
    bet_status = await bet_contract.get_bet_status().call()
    
    await master_contract.counter_bettor_judge_vote(user_id=bettor_public_key,address=bet_contract.contract_address).invoke()
    
    #Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_winner = bet_status.result.bet.bet_winner
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 3
    assert bet_winner == bettor_public_key

    print(f'Winner is user {bet_winner}')

    await master_contract.withdraw_funds(user_id=bettor_public_key,bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    execution_info=await account_contract.get_balance(user_id=bettor_public_key).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount + bet_amount,)