%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.constants.perpx_constants import (
    LIMIT,
    RANGE_CHECK_BOUND,
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
)
from contracts.perpx_v1_exchange.setters import (
    set_fee_rate,
    set_last_update_price_delta,
    reset_is_escaping,
)

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    %{
        context.self_address = ids.address
        store(context.self_address, "Ownable_owner", [ids.OWNER])
        store(context.self_address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
    %}
    return ();
}

// TEST SET FEE RATE

@external
func test_set_fee_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: valid fee rate than fee rate above 10_000
    let fee_rate = 150;
    %{ start_prank(ids.OWNER) %}
    set_fee_rate(fee_rate=fee_rate);
    %{
        f = load(context.self_address, "storage_volatility_fee_rate", "felt")[0]
        assert ids.fee_rate == f, f'fee rate error, expected {ids.fee_rate}, got {f}'
        expect_revert(error_message="fee rate limited to 10000")
    %}
    let fee_rate = 10001;
    set_fee_rate(fee_rate=fee_rate);
    return ();
}

// TEST SET LAST UPDATE PRICE DELTA

@external
func test_last_update_price_delta{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // test case: valid delta than delta above 30
    let delta = 20;
    %{ start_prank(ids.OWNER) %}
    set_last_update_price_delta(last_update_price_delta=delta);
    %{
        d = load(context.self_address, "storage_last_price_delta", "felt")[0]
        assert ids.delta == d, f'delta error, expected {ids.delta}, got {d}'
        expect_revert(error_message="delta limited to 30")
    %}

    let delta = 31;
    set_last_update_price_delta(last_update_price_delta=delta);
    return ();
}

// TEST SET IS ESCAPING

@external
func test_reset_is_escaping{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        store(context.self_address, "storage_is_escaping", [1])
        stop_prank = start_prank(ids.OWNER)
    %}
    reset_is_escaping();
    %{
        stop_prank()
        start_prank(ids.ACCOUNT)
        r = load(context.self_address, "storage_is_escaping", "felt")[0]
        assert r == 0, f'reset error, expected 0, got {r}'
        expect_revert(error_message="Ownable: caller is not the owner")
    %}

    reset_is_escaping();
    return ();
}
