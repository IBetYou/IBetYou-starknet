# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage

# Declare the interface with which to call the Market Maker contract.
@contract_interface
namespace IBet:
    func bet(market_a_pre : felt, market_b_pre : felt,
        user_gives_a : felt) -> (market_a_post : felt,
        market_b_post : felt, user_gets_b : felt):
    end
end





@l1_handler
func deposit{storage_ptr : Storage*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        from_address : felt, user : felt, amount : felt):
    # Make sure the message was sent by the intended L1 contract.
    assert from_address = L1_CONTRACT_ADDRESS

    # Read the current balance.
    let (res) = balance.read(user=user)

    # Compute and update the new balance.
    tempvar new_balance = res + amount
    balance.write(user, new_balance)

    return ()
end