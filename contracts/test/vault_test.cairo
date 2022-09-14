%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Vault, Stake
from contracts.perpx_v1_instrument import update_liquidity

@external
func provide_liquidity_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, owner: felt, instrument: felt
) -> () {
    Vault.provide_liquidity(amount=amount, owner=owner, instrument=instrument);
    return ();
}

@external
func withdraw_liquidity_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, owner: felt, instrument: felt
) -> () {
    Vault.withdraw_liquidity(amount=amount, owner=owner, instrument=instrument);
    return ();
}
