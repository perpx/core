%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import RANGE_CHECK_BOUND, LIMIT, MAX_BOUND, MIN_LIQUIDITY
from helpers.helpers import setup_helpers

//
// Setup
//

@external
func __setup__() {
    setup_helpers();
    %{ max_examples(200) %}
    return ();
}

//
// Tests
//

@external
func test_liquidity_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, long: felt, short: felt) {
    alloc_locals;
    local liquidity;
    %{
        # assumed limits when computing the fees
        assume(ids.short < ids.LIMIT and ids.long < ids.LIMIT and abs(ids.price*ids.amount) < ids.LIMIT)
        ids.liquidity = ids.MIN_LIQUIDITY
    %}

    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    );

    %{
        amount = context.signed_int(ids.amount)
        imbalance_fees = ids.price * amount * (2 * ids.long + ids.price * amount - 2 * ids.short) // (2 * ids.liquidity)

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}
    return ();
}

@external
func test_longs_shorts_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, liq: felt) {
    alloc_locals;
    local liquidity;
    %{
        assume(abs(ids.price*ids.amount) < ids.LIMIT)
        ids.liquidity = ids.liq % (ids.LIMIT - ids.MIN_LIQUIDITY) + ids.MIN_LIQUIDITY
    %}
    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=LIMIT, short=0, liquidity=liquidity
    );
    %{
        amount = context.signed_int(ids.amount)
        imbalance_fees = ids.price * amount * (2 * ids.LIMIT + ids.price * amount) // (2 * ids.liquidity)

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}
    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=0, short=LIMIT, liquidity=liquidity
    );
    %{
        imbalance_fees = ids.price * amount * (ids.price * amount - 2 * ids.LIMIT) // (2 * ids.liquidity)

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}
    return ();
}

@external
func test_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=LIMIT, amount=1, long=LIMIT, short=0, liquidity=MIN_LIQUIDITY
    );
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=1, amount=-LIMIT, long=0, short=LIMIT, liquidity=MIN_LIQUIDITY
    );
    return ();
}
