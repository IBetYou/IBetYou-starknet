# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (
    abs_value, assert_250_bit, assert_in_range, assert_le, assert_le_felt, assert_lt,
    assert_lt_felt, assert_nn, assert_nn_le, assert_not_equal, assert_not_zero, sign,
    signed_div_rem, split_felt, split_int, unsigned_div_rem)
# Define a storage variable.
@storage_var
func balance(user_id: felt) -> (res : felt):
end

@storage_var
func bettor() -> (res : felt):
end

@storage_var
func bet_text() -> (res : felt):
end

@storage_var
func counterBettor() -> (res : felt):
end

@storage_var
func bet_amount() -> (res : felt):
end

@storage_var
func bet_reserve_amount() -> (res : felt):
end

@storage_var
func bet_judge() -> (res : felt):
end

# Increases the balance by the given amount of a user_id.
@external
func increase_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt):
    let (res) = balance.read(user_id=user_id)
    balance.write(user_id, res + amount)
    return ()
end

struct Bet:
    member Better: felt
    member AntiBetter: felt
    member Judge: felt
    member Amount: felt
end

@external
func create_bet{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt, bet : felt) -> (res : Bet):
    assert_nn(amount)

    let (res) = balance.read(user_id=user_id)
    tempvar new_balance = res - amount

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(user_id, new_balance)
    bet_reserve_amount.write(amount)
   
    bettor.write(user_id)
    bet_amount.write(amount)
    bet_text.write(bet)
    let (b1) = bettor.read()
    let (b2) = counterBettor.read()
    let (j) = bet_judge.read()
    let (amt) = bet_amount.read()
    return( res = Bet (
        Better = b1,
        AntiBetter = b2,
        Judge = j,
        Amount = amt,
        )
    )
end

@external
func joinCounterBettor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt) -> (res : Bet):
    
    let (amt) = bet_amount.read()
    assert_nn(amt)
    let (res) = balance.read(user_id=user_id)
    tempvar new_balance = res - amt

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(user_id, new_balance)
    bet_reserve_amount.write(amt + amt)
    counterBettor.write(user_id)
    let (b1) = bettor.read()
    let (b2) = counterBettor.read()
    let (j) = bet_judge.read()
    let (amt) = bet_amount.read()
    
    return( res = Bet (
        Better = b1,
        AntiBetter = b2,
        Judge = j,
        Amount = amt,
        )
    )
end

@external
func vote_bettor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        judge : felt, bettor_id : felt) -> (res : Bet):
    
    let (amt) = bet_amount.read()
    let (b1) = bettor.read()
    let (b2) = counterBettor.read()
    let (j) = bet_judge.read()
    assert_nn(amt)
    assert_nn(b1)
    assert_nn(b2)
    assert_nn(j)
    assert j = judge
    let (res) = balance.read(user_id=bettor_id)
    let (prize) = bet_reserve_amount.read()
    tempvar new_balance = res + prize

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(bettor_id, new_balance)
    bet_reserve_amount.write(0)    
    
    return( res = Bet (
        Better = b1,
        AntiBetter = b2,
        Judge = j,
        Amount = amt,
        )
    )
end

@external
func join_judge{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt) -> (res : Bet):
    
    
    bet_judge.write(user_id)
    let (b1) = bettor.read()
    let (b2) = counterBettor.read()
    let (j) = bet_judge.read()
    let (amt) = bet_amount.read()
    
    return( res = Bet (
        Better = b1,
        AntiBetter = b2,
        Judge = j,
        Amount = amt,
        )
    )
end



func withdraw{
        syscall_ptr : felt*,  pedersen_ptr : HashBuiltin*, range_check_ptr}(
        user_id : felt, amount : felt):
    # Make sure 'amount' is positive.
    assert_nn(amount)

    let (res) = balance.read(user_id=user_id)
    tempvar new_balance = res - amount

    # Make sure the new balance will be positive.
    assert_nn(new_balance)

    # Update the new balance.
    balance.write(user_id, new_balance)
    return ()
end

# Returns the current balance of a user_id.
@view
func get_balance{
        syscall_ptr : felt*, pedersen_ptr : HashBuiltin*,
        range_check_ptr}(user_id: felt) -> (res : felt):
    let (res) = balance.read(user_id=user_id)
    return (res)
end

