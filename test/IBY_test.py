import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract



#Global var definition
master_contract = None
bet_contract = None
account_contract = None
starknet = None
BET_CONTRACT_FILE = ""

# Ids
bettor_id = 1
counter_bettor_id = 2
bettor_judge_id = 3
counter_bettor_judge_id = 4
admin_id = 5

# Amount variables
balance_amount = 50
bet_amount = 10

@pytest.fixture(autouse=True)
async def run_around_tests():
    global BET_CONTRACT_FILE
    # The path to the contract source code.
    # my change: modified the path to adapt to the file system
    BET_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "..", "contracts", "Bet.cairo")
    MASTER_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "..", "contracts", "Master.cairo")
    ACCOUNT_CONTRACT_FILE = os.path.join(
        os.path.dirname(__file__), "..", "contracts", "Account.cairo")
# Compile the contracts.
    master_contract_definition = compile_starknet_files(
        [MASTER_CONTRACT_FILE], debug_info=True)
    bet_contract_definition = compile_starknet_files(
        [BET_CONTRACT_FILE], debug_info=True)
    account_contract_definition = compile_starknet_files(
        [ACCOUNT_CONTRACT_FILE], debug_info=True)
    # Create a new Starknet class that simulates the StarkNet
    # system.
    global starknet
    starknet = await Starknet.empty()
    # Deploy the contracts.
    global master_contract
    global account_contract
    master_contract = await starknet.deploy(
        source=MASTER_CONTRACT_FILE)
    account_contract = await starknet.deploy(
        source=ACCOUNT_CONTRACT_FILE)



#####################################################
#                                                   #
#    Test bet happy flow, no dispute                #
#                                                   #
#####################################################
@pytest.mark.asyncio
async def test_normal_bet():
   
    print(f'Starting Happy flow test')
    global master_contract
    global bet_contract
    global account_contract

    # Create a new bet contract
    await generate_new_bet()
    
    # Confirm bet is in role assignment stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 1

    # Counter Bettor joins the bet
    await master_contract.join_counter_bettor(user_id=counter_bettor_id,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    
    # Check if amount is deducted from counter bettor account
    execution_info= await account_contract.get_balance(user_id=counter_bettor_id).call()
    counter_bettor_balance= execution_info.result
    assert counter_bettor_balance == (balance_amount-bet_amount,)
    print(f'Balance of User 2 after joining bet: {counter_bettor_balance.res}')

    # Judges join the bet
    await master_contract.join_bettor_judge(user_id=bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.join_counter_bettor_judge(user_id=counter_bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    
    # Confirm judges are in the bet and bet is in voting stage
    bet_status = await bet_contract.get_bet_status().call()
    bettor_judge = bet_status.result.bet.bettor_judge
    bet_state = bet_status.result.bet.bet_state
    counter_bettor_judge = bet_status.result.bet.counter_bettor_judge
    assert bettor_judge == bettor_judge_id
    assert counter_bettor_judge == counter_bettor_judge_id
    assert bet_state == 2

    # Judges vote for user 1
    await master_contract.bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.counter_bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    

    #Confirm user 1 is winner and bet is at withdrawal stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_winner = bet_status.result.bet.bet_winner
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 3
    assert bet_winner == bettor_id
    print(f'Winner is user {bet_winner}')

    #Withdraw funds to user 1's account and confirm bet is over
    await master_contract.withdraw_funds(bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    execution_info=await account_contract.get_balance(user_id=bettor_id).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount + bet_amount,)
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 4

    print(f'Happy flow test End')


#####################################################
#                                                   #
#           Test a bet with a dispute               #
#                                                   #
#####################################################
@pytest.mark.asyncio
async def test_dispute_bet():
    print(f'Starting dispute flow test')
    global master_contract
    global bet_contract
    global account_contract

    # Create a new bet contract
    await generate_new_bet()

    # Confirm bet is in role assignment stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 1
    
    # Counter Bettor joins the bet
    await master_contract.join_counter_bettor(user_id=counter_bettor_id,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    
    # Check if amount is deducted from counter bettor account
    execution_info= await account_contract.get_balance(user_id=counter_bettor_id).call()
    counter_bettor_balance= execution_info.result
    assert counter_bettor_balance == (balance_amount-bet_amount,)
    print(f'Balance of User 2 after joining bet: {counter_bettor_balance.res}')

    # Judges join the bet
    await master_contract.join_bettor_judge(user_id=bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.join_counter_bettor_judge(user_id=counter_bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    
    # Confirm judges are in the bet and bet is in voting stage
    bet_status = await bet_contract.get_bet_status().call()
    bettor_judge = bet_status.result.bet.bettor_judge
    bet_state = bet_status.result.bet.bet_state
    counter_bettor_judge = bet_status.result.bet.counter_bettor_judge
    assert bettor_judge == bettor_judge_id
    assert counter_bettor_judge == counter_bettor_judge_id
    assert bet_state == 2

    # Judge 1 votes for user 1 and Judge 2 votes for user 2
    await master_contract.bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.counter_bettor_judge_vote(user_id=counter_bettor_id,bet_address=bet_contract.contract_address).invoke()
    # Confirm the bet is in Dispute status
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 5
    


    # Admin solves dispute
    await master_contract.solve_dispute(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()

    # Check that user 1 is the winner and bet is in withdrawal stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_winner = bet_status.result.bet.bet_winner
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 3
    assert bet_winner == bettor_id
    print(f'Winner is user {bet_winner}')

    #Withdraw funds to user 1's account and confirm bet is over
    await master_contract.withdraw_funds(bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    execution_info=await account_contract.get_balance(user_id=bettor_id).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount + bet_amount,)
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 4
    print(f'Dispute flow test End')


#####################################################
#                                                   #
#           Bet state validations                   #
#                                                   #
#####################################################
@pytest.mark.asyncio
async def test_state_validations():
    print(f'Starting state validation test')
    global master_contract
    global bet_contract
    global account_contract

    # Create a new bet contract
    await generate_new_bet()

    # Confirm bet is in role assignment stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 1
    

    # Trying to vote before all roles have been assigned should result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"

    with pytest.raises(Exception) as excinfo:   
        await master_contract.counter_bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"


    # Trying to solve a dispute at this stage should also result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.solve_dispute(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"

    # Trying to withdraw funds at this stage should also result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.withdraw_funds(bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
        

    # Trying to assign an user that already has a role assigned to another role should result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.join_counter_bettor(user_id=bettor_id,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    with pytest.raises(Exception) as excinfo:   
        await master_contract.join_bettor_judge(user_id=bettor_id, bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    with pytest.raises(Exception) as excinfo:   
        await master_contract.join_counter_bettor_judge(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"


    # Counter bettor's judge joins the bet
    await master_contract.join_counter_bettor(user_id=counter_bettor_id,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    await master_contract.join_bettor_judge(user_id=bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.join_counter_bettor_judge(user_id=counter_bettor_judge_id,bet_address=bet_contract.contract_address).invoke()


    # Trying to reassign users to roles should result in error
    with pytest.raises(Exception) as excinfo:   
         await master_contract.join_counter_bettor(user_id=counter_bettor_id,amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    with pytest.raises(Exception) as excinfo:   
        await master_contract.join_bettor_judge(user_id=bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    with pytest.raises(Exception) as excinfo:   
        await master_contract.join_counter_bettor_judge(user_id=counter_bettor_judge_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"



    # Confirm bet is in voting stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 2

    # Trying to solve a dispute at this stage should also result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.solve_dispute(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    

    # Judge 1 votes for user 1 and Judge 2 votes for user 2
    await master_contract.bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    await master_contract.counter_bettor_judge_vote(user_id=counter_bettor_id,bet_address=bet_contract.contract_address).invoke()
    
    # Confirm the bet is in Dispute status
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 5

    # Trying to withdraw funds at this stage should also result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.withdraw_funds(bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"

    # Trying to vote again should result in error
    with pytest.raises(Exception) as excinfo:   
        await master_contract.bettor_judge_vote(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"
    with pytest.raises(Exception) as excinfo:   
        await master_contract.counter_bettor_judge_vote(user_id=counter_bettor_id,bet_address=bet_contract.contract_address).invoke()
    assert str(excinfo.value.code) == "StarknetErrorCode.TRANSACTION_FAILED"

    
    # Admin solves dispute
    await master_contract.solve_dispute(user_id=bettor_id,bet_address=bet_contract.contract_address).invoke()

    # Check that user 1 is the winner and bet is in withdrawal stage
    bet_status = await bet_contract.get_bet_status().call()
    bet_winner = bet_status.result.bet.bet_winner
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 3
    assert bet_winner == bettor_id
    print(f'Winner is user {bet_winner}')

    #Withdraw funds to user 1's account and confirm bet is over
    await master_contract.withdraw_funds(bet_address=bet_contract.contract_address, account_address=account_contract.contract_address).invoke()
    execution_info=await account_contract.get_balance(user_id=bettor_id).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount + bet_amount,)
    bet_status = await bet_contract.get_bet_status().call()
    bet_state = bet_status.result.bet.bet_state
    assert bet_state == 4
    print(f'State validation test End')





@pytest.mark.asyncio
async def generate_new_bet():
    global admin_id

    global master_contract
    global bet_contract
    global account_contract
    global starknet
    global BET_CONTRACT_FILE
    # Public keys
    global bettor_id
    global counter_bettor_id
    global bettor_judge_id
    global counter_bettor_id

    # Amount variables
    global balance_amount
    global bet_amount
    
    global bet_contract
    bet_contract = await starknet.deploy(
        source=BET_CONTRACT_FILE)

    await account_contract.add_balance(user_id=bettor_id, amount=balance_amount).invoke()
    await account_contract.add_balance(user_id=counter_bettor_id, amount=balance_amount).invoke()
    # Check the result of get_balance().
    execution_info=await account_contract.get_balance(user_id=bettor_id).call()
    bettor_balance= execution_info.result
    execution_info=await account_contract.get_balance(user_id=counter_bettor_id).call()
    counter_bettor_balance= execution_info.result

    assert bettor_balance == (balance_amount,)
    assert counter_bettor_balance == (balance_amount,)

    print(f'Balance of User 1: {bettor_balance.res}')
    print(f'Balance of User 2: {counter_bettor_balance.res}')

     # Create bet by bettor
    await master_contract.create_bet(user_id=bettor_id, amount=bet_amount, bet_address=bet_contract.contract_address, account_address=account_contract.contract_address, admin_id=admin_id).invoke()
    # Check if amount is deducted from user account
    execution_info=await account_contract.get_balance(user_id=bettor_id).call()
    bettor_balance= execution_info.result
    assert bettor_balance == (balance_amount-bet_amount,)
    print(f'Balance of User 1 after placing bet: {bettor_balance.res}')