# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.storage import Storage

# Define a storage variable.
@storage_var
func balance(user : felt) -> (res : felt):
end

@storage_var
func bet(user_id : felt, bet_id, bet_msg, amount) -> (bet : felt):
end

# Increases the balance by the given amount of a user.
@external
func increase_balance{
        storage_ptr : Storage*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, bet_id, bet_msg, amount):
    let (res) = balance.read(user=user)
    balance.write(user, res + amount)
    return ()
end

@external
func create_bet{
        storage_ptr : Storage*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user : felt, amount : felt):
    assert_nn(amount)

    let (res) = balance.read(user=user)
    tempvar new_balance = res - amount

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(user, new_balance)
    return ()
    
    return ()
end

@internal
func withdraw{
        syscall_ptr : felt*, storage_ptr : Storage*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user : felt, amount : felt):
    # Make sure 'amount' is positive.
    assert_nn(amount)

    let (res) = balance.read(user=user)
    tempvar new_balance = res - amount

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(user, new_balance)
    return ()
end

# Returns the current balance of a user.
@view
func get_balance{
        storage_ptr : Storage*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(user: felt) -> (res : felt):
    let (res) = balance.read(user=user)
    return (res)
end
