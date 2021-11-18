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
    os.path.dirname(__file__), "..", "contracts", "account.cairo")


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

    private_key = 12345
    amount = 4321
    message_hash = pedersen_hash(amount)
    public_key = private_to_stark_key(private_key)
    signature = sign(
        msg_hash=message_hash, priv_key=private_key)
    print(f'Public key: {public_key}')
    print(f'Signature: {signature}')
    # Deploy the contract.
    contract = await starknet.deploy(
        source=CONTRACT_FILE)
    # Invoke increase_balance().
    await contract.modify_account_balance(account_id=public_key, token_type=21, amount=amount).invoke(signature=list(signature))
    # Check the result of get_balance().
    execution_info=await contract.get_account_token_balance(account_id=public_key,token_type=21).call()
    balance= execution_info.result
    print(f'Balance: {balance}')
    assert balance == (amount,)