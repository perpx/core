%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.perpx_v1_exchange.storage import (
    storage_user_instruments,
    storage_oracles,
    storage_collateral,
    storage_instrument_count,
)

//
// MUTABLE
//

// @notice Returns instruments for which user has a position
// @param owner The owner of the positions
// @return instruments The owner's instruments
@view
func get_user_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt
) -> (instruments: felt) {
    let (instruments) = storage_user_instruments.read(owner);
    return (instruments=instruments);
}

// @notice Returns the price of the instrument
// @param instrument The instrument
// @return price The oracle's price for the instrument
@view
func get_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (price: felt) {
    let (price) = storage_oracles.read(instrument);
    return (price=price);
}

// @notice Returns the amount of collateral for the instrument
// @param owner The owner of the collateral
// @param instrument The collateral's instrument
// @return collateral The amount of collateral for the instrument
@view
func get_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instrument: felt
) -> (collateral: felt) {
    let (collateral) = storage_collateral.read(owner);
    return (collateral=collateral);
}

// @notice Returns the number of instruments
// @return count The number of instruments on the exchange
@view
func get_instrument_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    count: felt
) {
    let (count) = storage_instrument_count.read();
    return (count=count);
}
