%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.perpx_v1_instrument import storage_longs, storage_shorts
from contracts.perpx_v1_exchange.storage import (
    storage_user_instruments,
    storage_oracles,
    storage_prev_oracles,
    storage_volatility,
    storage_margin_parameters,
    storage_operations_count,
    storage_is_escaping,
)
from contracts.library.vault import storage_liquidity
from contracts.perpx_v1_exchange.structures import Parameter

// @notice Returns the user's instruments
// @params user The address of the user
// @return instruments The packed instruments of the user
@view
func view_user_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (instruments: felt) {
    return storage_user_instruments.read(user);
}

// @notice Returns the instrument's price
// @param instrument The instrument
// @return price The price of the instrument
@view
func view_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (price: felt) {
    return storage_oracles.read(instrument);
}

// @notice Returns the instrument's previous price
// @param instrument The instrument
// @return price The previous price of the instrument
@view
func view_prev_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (price: felt) {
    return storage_prev_oracles.read(instrument);
}

// @notice Returns the instrument's open interests
// @param instrument The instrument
// @return longs The open longs of the instrument
// @return shorts The open shorts of the instrument
@view
func view_open_interests{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (longs: felt, shorts: felt) {
    let (longs) = storage_longs.read(instrument);
    let (shorts) = storage_shorts.read(instrument);
    return (longs=longs, shorts=shorts);
}

// @notice Returns the instrument's liquidity
// @param instrument The instrument
// @return liquidity The provided liquidity on the instrument
@view
func view_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (liquidity: felt) {
    return storage_liquidity.read(instrument);
}

// @notice Returns the instrument's volatility
// @param instrument The instrument
// @return volatility The volatility for the instrument
@view
func view_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (volatility: felt) {
    return storage_volatility.read(instrument);
}

// @notice Returns the instrument's margin parameters
// @param instrument The instrument
// @return param The margin parameters k and tau for the instrument
@view
func view_margin_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (param: Parameter) {
    return storage_margin_parameters.read(instrument);
}

// @notice Returns the queued operations count
// @return count The queued operations count
@view
func view_operations_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    count: felt
) {
    return storage_operations_count.read();
}

// @notice Returns the escaping status of the contract
// @return escaping The escaping status of the contract
@view
func view_is_escaping{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    escaping: felt
) {
    return storage_is_escaping.read();
}
