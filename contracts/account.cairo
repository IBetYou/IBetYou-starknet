# Declare this file as a StarkNet contract and set the required
# builtins.
# Based on https://www.cairo-lang.org/docs/hello_starknet/user_auth.html and https://github.com/starkware-libs/cairo-lang/blob/master/src/starkware/starknet/apps/amm_sample/amm_sample.cairo
%lang starknet
%builtins pedersen range_check ecdsa


from starkware.cairo.common.math import assert_le, assert_nn_le, unsigned_div_rem, assert_nn
from starkware.cairo.common.cairo_builtins import (
    HashBuiltin, SignatureBuiltin)
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.signature import (
    verify_ecdsa_signature)
from starkware.starknet.common.syscalls import get_tx_signature, storage_read, storage_write

# A map from account and token type to the corresponding balance of that account.
@storage_var
func account_balance(account_id : felt, token_type : felt) -> (balance : felt):
end

# Adds amount to the account's balance for the given token.
# amount may be positive or negative.
@external
func modify_account_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
        account_id : felt, token_type : felt, amount : felt):
    # Fetch the signature.
    let (sig_len : felt, sig : felt*) = get_tx_signature()
    # Verify the signature length.
    assert sig_len = 2

    # Compute the hash of the message.
    # The hash of (x, 0) is equivalent to the hash of (x).
    let (amount_hash) = hash2{hash_ptr=pedersen_ptr}(amount, 0)

    # Verify the user's signature.
    verify_ecdsa_signature(
        message=amount_hash,
        public_key=account_id,
        signature_r=sig[0],
        signature_s=sig[1])
    let (current_balance) = account_balance.read(account_id, token_type)
    tempvar new_balance = current_balance + amount
    assert_nn(new_balance)
    account_balance.write(account_id=account_id, token_type=token_type, value=new_balance)
    return ()
end

# Returns the account's balance for the given token.
@view
func get_account_token_balance{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        account_id : felt, token_type : felt) -> (balance : felt):
    return account_balance.read(account_id, token_type)
end