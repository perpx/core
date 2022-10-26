%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.perpx_v1_exchange.storage import (
    storage_user_instruments,
    storage_oracles,
    storage_volatility,
    storage_margin_parameters,
)
from contracts.perpx_v1_exchange.structures import Parameter

@view
func view_user_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    user: felt
) -> (instruments: felt) {
    return storage_user_instruments.read(user);
}

@view
func view_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (price: felt) {
    return storage_oracles.read(instrument);
}

@view
func view_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (volatility: felt) {
    return storage_volatility.read(instrument);
}

@view
func view_margin_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (param: Parameter) {
    return storage_margin_parameters.read(instrument);
}
