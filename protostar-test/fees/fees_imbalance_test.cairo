%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import RANGE_CHECK_BOUND, LIMIT, MAX_BOUND, MIN_LIQUIDITY
from contracts.test.helpers import setup_helpers

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
        assume(ids.short < ids.LIMIT and ids.long < ids.LIMIT and abs(ids.price*ids.amount) < ids.LIMIT)
        amount = context.signed_int(ids.amount)
        price = ids.price
        long = ids.long
        short = ids.short
        ids.liquidity = ids.MIN_LIQUIDITY
        nom = price * amount * (2 * long + price * amount - 2 * short)
        denom = 2 * ids.liquidity
    %}

    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    );

    %{
        imbalance = context.signed_int(ids.imbalance_fees)
        imbalance_fees = nom // denom

        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}

    return ();
}

@external
func test_longs_shorts_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, liquidity: felt) {
    alloc_locals;
    local long = LIMIT;
    local short = LIMIT;
    local liq;
    %{
        assume(abs(ids.price*ids.amount) < ids.LIMIT)
        amount = context.signed_int(ids.amount)
        mod = ids.liquidity % (ids.LIMIT - 1) + 1
        ids.liq = mod if mod > ids.MIN_LIQUIDITY else mod + ids.MIN_LIQUIDITY
        price = ids.price
        long = ids.LIMIT
        short = 0
        nom = price * amount * (2 * long + price * amount - 2 * short)
        denom = 2 * ids.liq
    %}
    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=0, liquidity=liq
    );
    %{
        imbalance = context.signed_int(ids.imbalance_fees)
        imbalance_fees = nom // denom

        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}
    %{
        long = 0
        short = ids.LIMIT
        nom = price * amount * (2 * long + price * amount - 2 * short)
        denom = 2 * ids.liq
    %}
    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=0, short=short, liquidity=liq
    );
    %{
        imbalance = context.signed_int(ids.imbalance_fees)
        imbalance_fees = nom // denom

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
