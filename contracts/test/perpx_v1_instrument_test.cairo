%lang starknet

from contracts.perpx_v1_instrument import update_liquidity, update_long_short, longs, shorts
from contracts.library.vault import Vault, Stake
from starkware.cairo.common.cairo_builtins import HashBuiltin

@external
func update_liquidity_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, owner: felt, instrument: felt
) -> () {
    update_liquidity(amount, owner, instrument);
    return ();
}

@external
func update_long_short_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt, is_long: felt
) -> () {
    update_long_short(amount=amount, instrument=instrument, is_long=is_long);
    return ();
}

@view
func view_longs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (longs: felt) {
    let (_longs) = longs(instrument);
    return (longs=_longs);
}

@view
func view_shorts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (shorts: felt) {
    let (_shorts) = shorts(instrument);
    return (shorts=_shorts);
}

@view
func view_shares{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (shares: felt) {
    let (shares) = Vault.view_shares(instrument);
    return (shares=shares);
}

@view
func view_user_stake{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instrument: felt
) -> (stake: Stake) {
    let (stake) = Vault.view_user_stake(owner, instrument);
    return (stake=stake);
}

@view
func view_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (liquidity: felt) {
    let (liquidity) = Vault.view_liquidity(instrument);
    return (liquidity=liquidity);
}
