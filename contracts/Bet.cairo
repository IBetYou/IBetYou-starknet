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
    member admin: felt
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

######
#
#   Viewer functions
#
######

#/
#/  Get the winner of the bet
#/
@view
func get_bet_winner{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}()->(res : felt):

    let (res) = _bet.read(Bet.bet_winner)
    return (res)
end

#/
#/  Get the amount of the bet
#/
@view
func get_bet_amount{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}()->(res : felt):

    let (res) = _bet.read(Bet.bet_amount)
    return (res)
end

#/
#/  Get current status of the bet
#/
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
    let (admin) = _bet.read(Bet.admin)

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
        bet_winner=bet_winner,
        admin=admin
    )
    return (res)
end



######
#
#   Business logic
#
######

#/
#/  Creates the bet, assigning a user to the role of bettor
#/
@external
func create_bet{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt, amount : felt, admin_id : felt):
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = 0
    _bet.write(Bet.bet_state, BetStateEnum.ASSIGNING_PARTICIPANTS)
    _bet.write(Bet.bettor, user_id)
    _bet.write(Bet.admin, admin_id)
    _bet.write(Bet.bet_amount, amount)
    return()
end

#/
#/  Assigns a user to the role of the counter bettor
#/
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

#/
#/  Assigns a user to the role of the bettor's judge
#/
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


#/
#/  Assigns a user to the role of the counter bettor's judge
#/
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

#/
#/  Casts the vote of the bettor's judge
#/
@external
func bettor_judge_vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):

    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.VOTING_STAGE
    let (bettor_judge) = _bet.read(Bet.bettor_judge)
    assert_not_zero(bettor_judge)

    # Validate that this judge hasn't voted yet
    let (bettor_judge_voted) = _bet.read(Bet.bettor_judge_voted)
    assert bettor_judge_voted = 0
    _bet.write(Bet.bettor_judge_voted, 1)

    # Add vote to selected user
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


#/
#/  Casts the vote of the counter bettor's judge
#/
@external
func counter_bettor_judge_vote{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):

    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.VOTING_STAGE
    let (counter_bettor_judge) = _bet.read(Bet.counter_bettor_judge)
    assert_not_zero(counter_bettor_judge)

    # Validate that this judge hasn't voted yet
    let (counter_bettor_judge_voted) = _bet.read(Bet.counter_bettor_judge_voted)
    assert counter_bettor_judge_voted = 0
    _bet.write(Bet.counter_bettor_judge_voted, 1)

    # Add vote to selected user
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

#/
#/  The admin solves the dispute by voting, if a bet is in the dispute stage
#/
@external
func solve_dispute{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}(
        user_id : felt):

    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.DISPUTE
    let (admin) = _bet.read(Bet.admin)
    assert_not_zero(admin)

    
    # Add vote to selected user# Add vote to selected user
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
    _bet.write(Bet.bet_winner,user_id)
    _bet.write(Bet.bet_state,BetStateEnum.FUNDS_WITHDRAWAL)
    
    return()
end


#/
#/  Closes a bet
#/
@external
func set_bet_over{
        syscall_ptr : felt*, 
        pedersen_ptr : HashBuiltin*,
        range_check_ptr}():

    # Validate bet state
    let (betState) = _bet.read(Bet.bet_state)
    assert betState = BetStateEnum.FUNDS_WITHDRAWAL
    
    _bet.write(Bet.bet_state,BetStateEnum.BET_OVER)
    
    return()
end

#####################################################
#                                                   #
#            Internal helper functions              #
#                                                   #
#####################################################

#/
#/  Checks current voting status of bet
#/  If a judge hasn't voted yet, it remains in voting stage
#/  If both judges voted for the same user, the bet enters the withdrawal stage, where it waits for the winner to claim the reward
#/  If both judges voted for different users, the bet enters the dispute stage, where it waits for the admin to solve the dispute
#/
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

#/
#/  Checks current status of participant assignment
#/  If a role has not yet been filled, bet remains in the assignment stage
#/  If all roles have been assigned a user, it enters the voting stage
#/
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