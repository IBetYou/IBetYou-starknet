# Declare this file as a StarkNet contract and set the required
# builtins.
%lang starknet
%builtins pedersen range_check ecdsa

from starkware.cairo.common.math import (
    abs_value, assert_250_bit, assert_in_range, assert_le, assert_le_felt, assert_lt,
    assert_lt_felt, assert_nn, assert_nn_le, assert_not_equal, assert_not_zero, sign,
    signed_div_rem, split_felt, split_int, unsigned_div_rem)

from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin, SignatureBuiltin)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.signature import (
    verify_ecdsa_signature)
from starkware.starknet.common.syscalls import get_tx_signature

struct Bet:
    member bettor: felt
    member counter_bettor: felt
    member bettor_judge: felt
    member counter_bettor_judge: felt
    member bet_amount: felt
    member bet_state: felt
    member num_votes_bettor: felt
    member num_votes_counter_bettor: felt
    member bettor_judge_voted: felt
    member counter_bettor_judge_voted: felt
    member bet_winner: felt
end

struct BetStateEnum:
    member BET_CREATED: felt                #0
    member ASSIGNING_PARTICIPANTS: felt     #1
    member VOTING_STAGE: felt               #2
    member FUNDS_WITHDRAWAL: felt           #3
    member BET_OVER: felt                   #4
    member DISPUTE: felt                    #5
end

struct BooleanEnum:
    member TRUE: felt
    member FALSE: felt
end

@storage_var
func _bet(storage_index : felt) -> (res : felt):
end

#####################################################
#                                                   #
#   Functions to be called by the Master contract   #
#                                                   #
#####################################################

@view
func get_bet_winner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}()->(res : felt):

    let (res) = _bet.read(Bet.bet_winner)
    return (res)
end
@view
func get_bet_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}()->(res : felt):

    let (res) = _bet.read(Bet.bet_amount)
    return (res)
end


@view
func get_bet_status{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}()->(bet: Bet):

    let (bettor) = _bet.read(Bet.bettor)
    let (counter_bettor) = _bet.read(Bet.counter_bettor)
    let (bettor_judge) = _bet.read(Bet.bettor_judge)
    let (counter_bettor_judge) = _bet.read(Bet.counter_bettor_judge)
    let (bet_amount) = _bet.read(Bet.bet_amount)
    let (bet_state) = _bet.read(Bet.bet_state)
    let (num_votes_bettor) = _bet.read(Bet.num_votes_bettor)
    let (num_votes_counter_bettor) = _bet.read(Bet.num_votes_counter_bettor)
    let (bettor_judge_voted) = _bet.read(Bet.bettor_judge_voted)
    let (counter_bettor_judge_voted) = _bet.read(Bet.counter_bettor_judge_voted)
    let (bet_winner) = _bet.read(Bet.bet_winner)

    let res  = Bet(
        bettor=bettor,
        counter_bettor=counter_bettor,
        bettor_judge=bettor_judge,
        counter_bettor_judge=counter_bettor_judge,
        bet_amount=bet_amount,
        bet_state=bet_state,
        num_votes_bettor=num_votes_bettor,
        num_votes_counter_bettor=num_votes_counter_bettor,
        bettor_judge_voted=bettor_judge_voted,
        counter_bettor_judge_voted=counter_bettor_judge_voted,
        bet_winner=bet_winner
    )
    return (res)
end

@external
func create_bet{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt):
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = 0
    _bet.write(Bet.bet_state, BetStateEnum.ASSIGNING_PARTICIPANTS)
    _bet.write(Bet.bettor, user_id)
    _bet.write(Bet.bet_amount, amount)
    return()
end


@external
func join_counter_bettor{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.ASSIGNING_PARTICIPANTS

    # Validate that there is no counter bettor assigned
    let (counter_bettor) = _bet.read(Bet.counter_bettor)
    assert counter_bettor = 0

    # Validate that the counter bettor is not the same as any other participant
    let (bettor) = _bet.read(Bet.bettor)
    let (bettor_judge) = _bet.read(Bet.bettor_judge)
    let (counter_bettor_judge) = _bet.read(Bet.counter_bettor_judge)
    assert_not_equal(user_id,bettor)
    assert_not_equal(user_id,bettor_judge)
    assert_not_equal(user_id,counter_bettor_judge)
    _bet.write(Bet.counter_bettor, user_id)
    check_participants_bet_status()
    return()
end

@external
func join_bettor_judge{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.ASSIGNING_PARTICIPANTS

    # Validate that there is no bettor judge assigned
    let (bettor_judge) = _bet.read(Bet.bettor_judge)
    assert bettor_judge = 0

    # Validate that the bettor judge is not the same as any other participant
    let (bettor) = _bet.read(Bet.bettor)
    let (counter_bettor) = _bet.read(Bet.counter_bettor)
    let (counter_bettor_judge) = _bet.read(Bet.counter_bettor_judge)
    assert_not_equal(user_id,bettor)
    assert_not_equal(user_id,counter_bettor)
    assert_not_equal(user_id,counter_bettor_judge)
    _bet.write(Bet.bettor_judge, user_id)
    check_participants_bet_status()
    return()
end

@external
func join_counter_bettor_judge{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.ASSIGNING_PARTICIPANTS

    # Validate that there is no counter bettor judge assigned
    let (counter_bettor_judge) = _bet.read(Bet.counter_bettor_judge)
    assert counter_bettor_judge = 0

    # Validate that the bettor judge is not the same as any other participant
    let (bettor) = _bet.read(Bet.bettor)
    let (counter_bettor) = _bet.read(Bet.counter_bettor)
    let (bettor_judge) = _bet.read(Bet.bettor_judge)
    assert_not_equal(user_id,bettor)
    assert_not_equal(user_id,counter_bettor)
    assert_not_equal(user_id,bettor_judge)
    _bet.write(Bet.counter_bettor_judge, user_id)
    check_participants_bet_status()
    return()
end


@external
func bettor_judge_vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):
    # let (sig_len : felt, sig : felt*) = get_tx_signature()
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.VOTING_STAGE

    # Validate that the user calling this function is the judge
    # Compute the hash of the message.
    # The hash of (x, 0) is equivalent to the hash of (x).
    let (bettor_judge_id) = _bet.read(Bet.bettor_judge)
    let (bettor_id_hash) = hash2{hash_ptr=pedersen_ptr}(bettor_judge_id, 0)

    # Verify the user's signature.
    #verify_ecdsa_signature(
    #    message=bettor_id_hash,
     #   public_key=judge,
      #  signature_r=sig[0],
       # signature_s=sig[1])

    # Validate that bettor judge hasn't voted yet
    let (bettor_judge_voted) = _bet.read(Bet.bettor_judge_voted)
    assert bettor_judge_voted = 0
    _bet.write(Bet.bettor_judge_voted, 1)
    let (bettor_id) = _bet.read(Bet.bettor)
    let (counter_bettor_id) = _bet.read(Bet.counter_bettor)
    let (num_votes_bettor) = _bet.read(Bet.num_votes_bettor)
    let (num_votes_counter_bettor) = _bet.read(Bet.num_votes_counter_bettor)

    if bettor_id == user_id:   
       _bet.write(Bet.num_votes_bettor, num_votes_bettor+1)
    else:
        assert counter_bettor_id = user_id
        _bet.write(Bet.num_votes_counter_bettor, num_votes_counter_bettor+1)
    end
    check_voting_status()
    return()
end

@external
func counter_bettor_judge_vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):
    # let (sig_len : felt, sig : felt*) = get_tx_signature()
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.VOTING_STAGE

    # Validate that the user calling this function is the judge
    # Compute the hash of the message.
    # The hash of (x, 0) is equivalent to the hash of (x).
    let (counter_bettor_judge_id) = _bet.read(Bet.bettor_judge)
    let (bettor_id_hash) = hash2{hash_ptr=pedersen_ptr}(counter_bettor_judge_id, 0)

    # Verify the user's signature.
    #verify_ecdsa_signature(
    #    message=bettor_id_hash,
     #   public_key=judge,
      #  signature_r=sig[0],
       # signature_s=sig[1])

    # Validate that bettor judge hasn't voted yet
    let (counter_bettor_judge_voted) = _bet.read(Bet.counter_bettor_judge_voted)
    assert counter_bettor_judge_voted = 0
    _bet.write(Bet.counter_bettor_judge_voted, 1)
    let (bettor_id) = _bet.read(Bet.bettor)
    let (counter_bettor_id) = _bet.read(Bet.counter_bettor)
    let (num_votes_bettor) = _bet.read(Bet.num_votes_bettor)
    let (num_votes_counter_bettor) = _bet.read(Bet.num_votes_counter_bettor)
    if bettor_id == user_id:   
       _bet.write(Bet.num_votes_bettor, num_votes_bettor+1)
    else:
        assert counter_bettor_id = user_id
        _bet.write(Bet.num_votes_counter_bettor, num_votes_counter_bettor+1)
    end
    check_voting_status()
    return()
end


@external
func dispute_vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        voter_id : felt, user_id : felt):
    # let (sig_len : felt, sig : felt*) = get_tx_signature()
    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.DISPUTE

    # Validate that the user calling this function is the judge
    # Compute the hash of the message.
    # The hash of (x, 0) is equivalent to the hash of (x).
    let (voter_id_hash) = hash2{hash_ptr=pedersen_ptr}(voter_id, 0)

    # Verify the user's signature.
    #verify_ecdsa_signature(
    #    message=bettor_id_hash,
     #   public_key=voter_id,
      #  signature_r=sig[0],
       # signature_s=sig[1])

    # Validate that bettor judge hasn't voted yet
    let (counter_bettor_judge_voted) = _bet.read(Bet.counter_bettor_judge_voted)
    assert counter_bettor_judge_voted = 0
    _bet.write(Bet.counter_bettor_judge_voted, 1)
    let (bettor_id) = _bet.read(Bet.bettor)
    let (counter_bettor_id) = _bet.read(Bet.counter_bettor)
    let (num_votes_bettor) = _bet.read(Bet.num_votes_bettor)
    let (num_votes_counter_bettor) = _bet.read(Bet.num_votes_counter_bettor)
    if bettor_id == user_id:   
       _bet.write(Bet.num_votes_bettor, num_votes_bettor+1)
    else:
        assert counter_bettor_id = user_id
        _bet.write(Bet.num_votes_counter_bettor, num_votes_counter_bettor+1)
    end
    check_voting_status()
    return()
end




func check_voting_status{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}():
    let (betState) = _bet.read(Bet.bet_state)

    assert betState = BetStateEnum.VOTING_STAGE

    let (bettor_judge_voted) = _bet.read(Bet.bettor_judge_voted)
    let (counter_bettor_judge_voted) = _bet.read(Bet.bettor_judge_voted)
    let (num_votes_bettor) = _bet.read(Bet.num_votes_bettor)
    let (num_votes_counter_bettor) = _bet.read(Bet.num_votes_counter_bettor)
    let (bettor_id) = _bet.read(Bet.bettor)
    let (counter_bettor_id) = _bet.read(Bet.counter_bettor)
    if bettor_judge_voted == 0:
        _bet.write(Bet.bet_state, BetStateEnum.VOTING_STAGE)
        return()
    end
    if counter_bettor_judge_voted == 0:
        _bet.write(Bet.bet_state, BetStateEnum.VOTING_STAGE)
        return()
    end
    if num_votes_bettor == num_votes_counter_bettor:
        _bet.write(Bet.bet_state, BetStateEnum.DISPUTE)
        return()
    end    
    if num_votes_bettor == 2:
        _bet.write(Bet.bet_winner,bettor_id)
        _bet.write(Bet.bet_state, BetStateEnum.FUNDS_WITHDRAWAL)
        return()
    end
    if num_votes_counter_bettor == 2:
        _bet.write(Bet.bet_winner, counter_bettor_id)
        _bet.write(Bet.bet_state, BetStateEnum.FUNDS_WITHDRAWAL)
        return()
    end
    return()
end

func check_participants_bet_status{
        syscall_ptr : felt*,
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}():

    let (betState) = _bet.read(Bet.bet_state)

    assert betState = BetStateEnum.ASSIGNING_PARTICIPANTS

    let (counter_bettor) = _bet.read(Bet.counter_bettor)
    let (judge) = _bet.read(Bet.bettor_judge)
    let (counter_judge) = _bet.read(Bet.counter_bettor_judge)

    if counter_bettor == 0:
        _bet.write(Bet.bet_state, BetStateEnum.ASSIGNING_PARTICIPANTS)
        return()
    end
    if judge == 0:
        _bet.write(Bet.bet_state, BetStateEnum.ASSIGNING_PARTICIPANTS)
        return()
    end
    if counter_judge == 0:
        _bet.write(Bet.bet_state, BetStateEnum.ASSIGNING_PARTICIPANTS)
        return()
    end
    _bet.write(Bet.bet_state, BetStateEnum.VOTING_STAGE)
    return()
end    