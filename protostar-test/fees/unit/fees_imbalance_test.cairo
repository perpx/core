%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import RANGE_CHECK_BOUND, LIMIT, MAX_BOUND, MIN_LIQUIDITY

//
// Setup
//

@external
func __setup__() {
    %{
        import importlib  
        utils = importlib.import_module("protostar-test.utils")
        context.signed_int = utils.signed_int
        max_examples(utils.read_max_examples("./config.yml"))
    %}
    return ();
}

//
// Tests
//

@external
func setup_liquidity_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{
        given(
            amount=strategy.integers(-ids.LIMIT, ids.LIMIT).filter(lambda x: x != 0),
            long=strategy.integers(0, ids.LIMIT),
            short=strategy.integers(0,ids.LIMIT),
        )
    %}
    return ();
}

@external
func test_liquidity_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(amount: felt, long: felt, short: felt) {
    alloc_locals;
    local liquidity;
    local price;
    %{
        ids.liquidity = ids.MIN_LIQUIDITY
        amount = context.signed_int(ids.amount)
        ids.price = ids.LIMIT // abs(amount)
    %}

    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    );

    %{
        imbalance_fees = ids.price * amount * (2 * ids.long + ids.price * amount - 2 * ids.short) // (2 * ids.liquidity)

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
    %}
    return ();
}

@external
func setup_longs_shorts_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{
        given(
            amount=strategy.integers(-ids.LIMIT, ids.LIMIT).filter(lambda x: x != 0),
            liquidity=strategy.integers(ids.MIN_LIQUIDITY, ids.LIMIT),
        )
    %}
    return ();
}

@external
func test_longs_shorts_compute_imbalance_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(amount: felt, liquidity: felt) {
    alloc_locals;
    local price;
    %{
        amount = context.signed_int(ids.amount)
        ids.price = ids.LIMIT // abs(amount)
    %}
    // compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=LIMIT, short=0, liquidity=liquidity
    );
    %{
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
