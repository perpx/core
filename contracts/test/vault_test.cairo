%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import (
    Vault,
    Stake,
    storage_liquidity,
    storage_shares,
    storage_user_stake,
)

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

@view
func view_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (liquidity: felt) {
    let (liquidity) = storage_liquidity.read(instrument);
    return (liquidity=liquidity);
}

@view
func view_user_stake{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instrument: felt
) -> (stake: Stake) {
    let (stake) = storage_user_stake.read(owner, instrument);
    return (stake=stake);
}

@view
func view_shares{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (shares: felt) {
    let (shares) = storage_shares.read(instrument);
    return (shares=shares);
}
