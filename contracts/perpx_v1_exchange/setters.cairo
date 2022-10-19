%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.utils.access_control import assert_only_owner

from contracts.perpx_v1_exchange.storage import storage_last_price_delta, storage_is_escaping
from contracts.library.fees import storage_volatility_fee_rate

// @notice Sets the volatility fee rate
// @dev fee_rate limited to 10_000
// @param fee_rate The volatility fee rate in bips (precision: 4)
@external
func set_fee_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(fee_rate: felt) {
    assert_only_owner();
    let fee_rate_limit = 10000;
    with_attr error_message("fee rate limited to {fee_rate_limit}") {
        assert [range_check_ptr] = fee_rate;
        assert [range_check_ptr + 1] = fee_rate_limit - fee_rate;
    }
    let range_check_ptr = range_check_ptr + 2;
    storage_volatility_fee_rate.write(fee_rate);
    return ();
}

// @notice Sets last update price delta
// @dev delta limited to 30 minutes
// @param last_update_price_delta The time delta in minutes allowed between two price updates
@external
func set_last_update_price_delta{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    last_update_price_delta: felt
) {
    assert_only_owner();
    let last_update_price_delta_limit = 30;
    with_attr error_message("delta limited to {last_update_price_delta_limit}") {
        assert [range_check_ptr] = last_update_price_delta;
        assert [range_check_ptr + 1] = last_update_price_delta_limit - last_update_price_delta;
    }
    let range_check_ptr = range_check_ptr + 2;
    storage_last_price_delta.write(last_update_price_delta);
    return ();
}

// @notice Reset the escaping status of the contract to 0
@external
func reset_is_escaping{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    assert_only_owner();
    storage_is_escaping.write(0);
    return ();
}
