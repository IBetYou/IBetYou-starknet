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
CONTRACT_FILE = os.path.join(
    os.path.dirname(__file__), "..", "contracts", "contract.cairo")


# The testing library uses python's asyncio. So the following
# decorator and the ``async`` keyword are needed.
@pytest.mark.asyncio
async def test_increase_balance():
    # Compile the contract.
    contract_definition = compile_starknet_files(
        [CONTRACT_FILE], debug_info=True)

    # Create a new Starknet class that simulates the StarkNet
    # system.
    starknet = await Starknet.empty()

    # Deploy the contract.
    contract = await starknet.deploy(
        source=CONTRACT_FILE)


   

    # Amount variables
    balance_amount = 50
    bet_amount = 10
    balance_ammount_message_hash = pedersen_hash(balance_amount)
    bet_amount_message_hash = pedersen_hash(bet_amount)

    #user_id 1 = bettor
    #user_id 2 = counter_bettor
    #user_id 3 = judge
    # Generate keys and signature
    
    # Bettor private key
    private_key_1 = 12345
    # Counter Bettor private key
    private_key_2 = 54321
    # Judge private key
    private_key_3 = 51423
    public_key_1 = private_to_stark_key(private_key_1)
    user_1_message_hash = pedersen_hash(public_key_1)
    public_key_2 = private_to_stark_key(private_key_2)
    public_key_3 = private_to_stark_key(private_key_3)
    judge_message_hash = pedersen_hash(public_key_1)

    # Generate Hashes for the messages
    balance_signature_1 = sign(
        msg_hash=balance_ammount_message_hash, priv_key=private_key_1)
    balance_signature_2 = sign(
        msg_hash=balance_ammount_message_hash, priv_key=private_key_2)

    bet_amount_signature_1 = sign(
        msg_hash=bet_amount_message_hash, priv_key=private_key_1)
    bet_amount_signature_2 = sign(
        msg_hash=bet_amount_message_hash, priv_key=private_key_2)

    judge_signature = sign(
        msg_hash=judge_message_hash, priv_key=private_key_3)
    # Invoke increase_balance().
    await contract.increase_balance(user_id=public_key_1, amount=balance_amount).invoke(signature=list(balance_signature_1))
    await contract.increase_balance(user_id=public_key_2, amount=balance_amount).invoke(signature=list(balance_signature_2))

    # Check the result of get_balance().
    execution_info_1=await contract.get_balance(user_id=public_key_1).call()
    execution_info_2=await contract.get_balance(user_id=public_key_2).call()
    balance_1= execution_info_1.result
    balance_2= execution_info_2.result

    assert balance_1 == (balance_amount,)
    assert balance_2 == (balance_amount,)

    print(f'Balance of User {public_key_1}: {balance_1}')
    print(f'Balance of User {public_key_2}: {balance_2}')

    # Create bet by bettor
    await contract.createBet(user_id=public_key_1, amount=10, bet=10098).invoke(signature=list(bet_amount_signature_1))
    # Check if amount is deducted from user account
    execution_info_1=await contract.get_balance(user_id=public_key_1).call()
    balance_1= execution_info_1.result
    assert balance_1 == (balance_amount-bet_amount,)
    print(f'Balance of User {public_key_1} after placing bet: {balance_1}')

    # User_id 2 joins the bet
    await contract.joinCounterBettor(user_id=public_key_2).invoke()
    # Check if amount is deducted from counter bettor account
    execution_info_2= await contract.get_balance(user_id=public_key_2).call()
    balance_2= execution_info_2.result
    assert balance_2 == (balance_amount-bet_amount,)
    print(f'Balance of User {public_key_2} after joining bet: {balance_2}')

    #judge joins the bet
    await contract.joinJudge(user_id=public_key_3).invoke()
    #Judge votes user_id 1 as winner
    await contract.voteBettor(judge=public_key_3, bettor_id=public_key_1).invoke(signature=list(judge_signature))

     # Check if balance of user_id 1 is higher than the original
    execution_info_1=await contract.get_balance(user_id=public_key_1).call()
    balance_1= execution_info_1.result
    assert balance_1 == (balance_amount+bet_amount,)
     # Check if balance of user_id 2 is lower than the original

    execution_info_2=await contract.get_balance(user_id=public_key_2).call()
    balance_2= execution_info_2.result
    assert balance_2 == (balance_amount-bet_amount,)
    print(f'Balance of User {public_key_1} after winning bet: {balance_1}')
    print(f'Balance of User {public_key_2} after losing bet: {balance_2}')

