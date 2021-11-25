# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.math import (
    abs_value, assert_250_bit, assert_in_range, assert_le, assert_le_felt, assert_lt,
    assert_lt_felt, assert_nn, assert_nn_le, assert_not_equal, assert_not_zero, sign,
    signed_div_rem, split_felt, split_int, unsigned_div_rem)
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin, SignatureBuiltin)

# Define a storage variable.
@storage_var
func _balance(user_id : felt) -> (res : felt):
end

# Adds to the balance by the given amount of a user_id.
@external
func add_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
        user_id : felt, amount : felt):
    let (res) = _balance.read(user_id=user_id)
    _balance.write(user_id, res + amount)
    return ()
end


# Returns the current balance of a user_id.
@view
func get_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(user_id : felt) -> (res : felt):
    let (res) = _balance.read(user_id=user_id)
    return (res)
end

