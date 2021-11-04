import os
import pytest

from starkware.starknet.compiler.compile import (
    compile_starknet_files)
from starkware.starknet.testing.starknet import Starknet
from starkware.starknet.testing.contract import StarknetContract

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
    contract_address = await starknet.deploy(
        contract_definition=contract_definition)
    contract = StarknetContract(
        starknet=starknet,
        abi=contract_definition.abi,
        contract_address=contract_address,
    )
    #user_id 1 = better
    #user_id 2 = anti_better
    #user_id 3 = judge
    # Invoke increase_balance().
    await contract.increase_balance(user_id=1, amount=20).invoke()
    await contract.increase_balance(user_id=2, amount=20).invoke()
    # Check the result of get_balance().
    assert await contract.get_balance(user_id=1).call() == (20,)
    assert await contract.get_balance(user_id=2).call() == (20,)

    # Create bet by user_id 1
    await contract.create_bet(user_id=1, amount=10, bet=10098).invoke()
    # Check if amount is deducted from user account
    assert await contract.get_balance(user_id=1).call() == (10,)
    # User_id 2 joins the bet
    await contract.join_anti_better(user_id=2).invoke()
    # Check if amount is deducted from anti better account
    assert await contract.get_balance(user_id=2).call() == (10,)
    #judge joins the bet
    await contract.join_judge(user_id=3).invoke()
    #Judge votes user_id 1 as winner
    await contract.vote_better(judge=3, better_id=1).invoke()