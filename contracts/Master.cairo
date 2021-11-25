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

@contract_interface
namespace IBet:

    func create_bet(user_id : felt, amount : felt):
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


@external
func create_bet{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt, bet_address : felt, account_address : felt):
    assert_nn(amount)
    assert_not_zero(amount)
    let (user_balance) = IAccount.get_balance(account_address,user_id)
    assert_le(amount,user_balance)
    IAccount.add_balance(account_address,user_id,0-amount)
    IBet.create_bet(bet_address,user_id,amount)
    _bet_map.write(bet_address, BetUsers.bettor, user_id)
    return()
end


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

@external
func join_bettor_judge{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, address : felt):
    IBet.join_bettor_judge(address,user_id)
    _bet_map.write(address, BetUsers.bettor_judge, user_id)
    return()
end

@external
func join_counter_bettor_judge{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, address : felt):
    IBet.join_counter_bettor_judge(address,user_id)
    _bet_map.write(address, BetUsers.counter_bettor_judge, user_id)
    return()
end

@external
func bettor_judge_vote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, address : felt):
    IBet.bettor_judge_vote(address,user_id)
    check_winner(address)
    return()
end

@external
func counter_bettor_judge_vote{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, address : felt):
    IBet.counter_bettor_judge_vote(address,user_id)
    check_winner(address)
    return()
end

@external
func withdraw_funds{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(user_id : felt,bet_address : felt,account_address : felt):
    
    let (winner_id) = _bet_map.read(bet_address,BetUsers.winner)
    assert winner_id = user_id
    # Validate that the user calling this function is the winner
    # Compute the hash of the message.
    # The hash of (x, 0) is equivalent to the hash of (x).
    let (winner_id) = _bet_map.read(bet_address,BetUsers.winner)
    let (winner_id_hash) = hash2{hash_ptr=pedersen_ptr}(winner_id, 0)
    # Verify the user's signature.
    #verify_ecdsa_signature(
    #    message=bettor_id_hash,
     #   public_key=winner_id,
      #  signature_r=sig[0],
       # signature_s=sig[1])
    
    let (amount) = IBet.get_bet_amount(bet_address)
    IAccount.add_balance(account_address,user_id,2*amount)
    return()
end

@view
func get_bet_bettor{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(address: felt) -> (res : felt):
    let (res) = _bet_map.read(address,BetUsers.bettor)
    return(res)
end


func check_winner{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(address: felt) -> ():
    let (res) = IBet.get_bet_winner(address)
    _bet_map.write(address,BetUsers.winner,res)
    return()
end
