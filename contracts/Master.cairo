# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.math import (
    abs_value, assert_250_bit, assert_in_range, assert_le, assert_le_felt, assert_lt,
    assert_lt_felt, assert_nn, assert_nn_le, assert_not_equal, assert_not_zero, sign,
    signed_div_rem, split_felt, split_int, unsigned_div_rem)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin, SignatureBuiltin)

struct BetUsers:
    member bettor: felt
    member counter_bettor: felt
    member bettor_judge: felt
    member counter_bettor_judge: felt
    member winner: felt
end


@storage_var
func _bet_map(address: felt, storage_index : felt) -> (res : felt):
end
#####################################################
#                                                   #
#           External Interfaces Definition          #
#                                                   #
#####################################################
@contract_interface
namespace IBet:

    func create_bet(user_id : felt, amount : felt, admin_id : felt):
    end

    func join_counter_bettor(user_id : felt):
    end

    func join_bettor_judge(user_id : felt):
    end

    func join_counter_bettor_judge(user_id : felt):
    end

    func bettor_judge_vote(user_id : felt):
    end

    func counter_bettor_judge_vote(user_id : felt):
    end

    func solve_dispute(user_id : felt):
    end

    func set_bet_over():
    end

    func get_bet_winner()->(res : felt):
    end

    func get_bet_amount()->(res : felt):
    end
end

@contract_interface
namespace IAccount:
    func add_balance(user_id : felt, amount : felt):
    end
    func get_balance(user_id : felt) -> (res : felt):
    end
end



#####################################################
#                                                   #
#      Functions to be called by the frontend       #
#                                                   #
#####################################################

#/
#/  Initialize the bet on the target bet address
#/
@external
func create_bet{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt, bet_address : felt, account_address : felt, admin_id : felt):
    assert_nn(amount)
    assert_not_zero(amount)
    assert_not_zero(user_id)
    assert_not_zero(admin_id)
    let (user_balance) = IAccount.get_balance(account_address,user_id)
    assert_le(amount,user_balance)
    IAccount.add_balance(account_address,user_id,0-amount)
    IBet.create_bet(bet_address,user_id,amount, admin_id)
    _bet_map.write(bet_address, BetUsers.bettor, user_id)
    return()
end

#/
#/  Adds counter bettor to the bet
#/
@external
func join_counter_bettor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*, 
        range_check_ptr}(
        user_id : felt, amount : felt, bet_address : felt, account_address : felt):
    let (user_balance) = IAccount.get_balance(account_address,user_id)
    assert_le(amount,user_balance)
    IAccount.add_balance(account_address,user_id,0-amount)
    IBet.join_counter_bettor(bet_address,user_id)
    _bet_map.write(bet_address, BetUsers.counter_bettor, user_id)
    return()
end

#/
#/  Adds bettor's judge to the bet
#/
@external
func join_bettor_judge{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, bet_address : felt):
    IBet.join_bettor_judge(bet_address,user_id)
    _bet_map.write(bet_address, BetUsers.bettor_judge, user_id)
    return()
end

#/
#/  Adds counter bettor's judge to the bet
#/
@external
func join_counter_bettor_judge{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, bet_address : felt):
    IBet.join_counter_bettor_judge(bet_address,user_id)
    _bet_map.write(bet_address, BetUsers.counter_bettor_judge, user_id)
    return()
end

#/
#/  Casts bettor's judge's vote on a bet
#/
@external
func bettor_judge_vote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, bet_address : felt):
    IBet.bettor_judge_vote(bet_address,user_id)
    check_winner(bet_address)
    return()
end

#/
#/  Casts counter bettor's judge's vote on a bet
#/
@external
func counter_bettor_judge_vote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, bet_address : felt):
    IBet.counter_bettor_judge_vote(bet_address,user_id)
    check_winner(bet_address)
    return()
end

#/
#/  Withdraws the funds to the winner
#/
@external
func withdraw_funds{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        bet_address : felt, account_address : felt):
    
    let (winner_id) = _bet_map.read(bet_address,BetUsers.winner)
    assert_not_zero(winner_id)
    
    let (amount) = IBet.get_bet_amount(bet_address)
    IBet.set_bet_over(bet_address)
    IAccount.add_balance(account_address,winner_id,amount+amount)
    return()
end


#/
#/  Admin solves dispute
#/
@external
func solve_dispute{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_address : felt, user_id : felt):
    
    IBet.solve_dispute(bet_address,user_id)
    check_winner(bet_address)
    return()
end



#####################################################
#                                                   #
#           Internal and helper functions           #
#                                                   #
#####################################################

#/
#/  Get a bet's bettor
#/
@view
func get_bet_bettor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_address : felt) -> (res : felt):
    let (res) = _bet_map.read(bet_address,BetUsers.bettor)
    return(res)
end

#/
#/  Check the bet to see if there's a winner assigned
#/
func check_winner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_address : felt) -> ():
        
    let (res) = IBet.get_bet_winner(bet_address)
    if res != 0:
        _bet_map.write(bet_address,BetUsers.winner,res)
        return()
    end
    return()
end


@view
func get_winner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(bet_address : felt) -> (res : felt):
    let (res) = _bet_map.read(bet_address,BetUsers.winner)
    return(res)
end