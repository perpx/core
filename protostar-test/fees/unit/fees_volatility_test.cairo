%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.library.fees import Fees, storage_volatility_fee_rate
from contracts.constants.perpx_constants import LIMIT, MIN_LIQUIDITY

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    %{
        import importlib  
        utils = importlib.import_module("protostar-test.utils")
        context.signed_int = utils.signed_int
        max_examples(utils.read_max_examples("./config.yml"))
        context.self_address = ids.address
    %}
    return ();
}

//
// Tests
//

@external
func setup_liquidity_compute_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    %{
        given(
            amount=strategy.integers(-ids.LIMIT, ids.LIMIT).filter(lambda x: x != 0),
            long=strategy.integers(0, ids.LIMIT),
            short=strategy.integers(0,ids.LIMIT),
            fee_rate=strategy.integers(0, 10000)
        )
    %}
    return ();
}

@external
func test_liquidity_compute_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, long: felt, short: felt, fee_rate: felt
) -> () {
    alloc_locals;
    local price;
    %{
        amount = context.signed_int(ids.amount)
        ids.price = ids.LIMIT // abs(amount)
        store(context.self_address, "storage_volatility_fee_rate", [ids.fee_rate], key=[])
    %}
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=MIN_LIQUIDITY
    );
    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=MIN_LIQUIDITY
    );
    %{
        imbalance_fees = ids.price * amount * (2*ids.long + ids.price * amount - 2* ids.short) // 10**12 // (2 * ids.MIN_LIQUIDITY)
        volatility_fee = (abs(imbalance_fees) * ids.fee_rate) // 10**4

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fees error, expected {imbalance_fees}, got {imbalance}'

        fees = context.signed_int(ids.fees)
        assert imbalance_fees + volatility_fee == fees, f'fees error, expected {imbalance_fees + volatility_fee}, got {fees}'
    %}
    return ();
}

@external
func setup_longs_shorts_compute_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{
        given(
            amount=strategy.integers(-ids.LIMIT, ids.LIMIT).filter(lambda x: x != 0),
            liquidity=strategy.integers(ids.MIN_LIQUIDITY, ids.LIMIT),
            fee_rate=strategy.integers(0, 10000)
        )
    %}
    return ();
}

@external
func test_longs_shorts_compute_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(amount: felt, liquidity: felt, fee_rate: felt) {
    alloc_locals;
    local price;
    %{
        amount = context.signed_int(ids.amount)
        ids.price = ids.LIMIT // abs(amount)
        store(context.self_address, "storage_volatility_fee_rate", [ids.fee_rate], key=[])
    %}
    // compute fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=LIMIT, short=0, liquidity=liquidity
    );
    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=LIMIT, short=0, liquidity=liquidity
    );
    %{
        imbalance_fees = ids.price * amount * (2 * ids.LIMIT + ids.price * amount) // 10**12 // (2 * ids.liquidity)
        volatility_fees = abs(imbalance_fees) * ids.fee_rate // 10**4

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'

        fees = context.signed_int(ids.fees)
        assert imbalance_fees + volatility_fees == fees, f'volatility fee error, expected {imbalance_fees + volatility_fees}, got {fees}'
    %}
    // compute fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=0, short=LIMIT, liquidity=liquidity
    );
    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=0, short=LIMIT, liquidity=liquidity
    );
    %{
        imbalance_fees = ids.price * amount * (ids.price * amount - 2 * ids.LIMIT) // 10**12 // (2 * ids.liquidity)
        volatility_fees = abs(imbalance_fees) * ids.fee_rate // 10**4

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'

        fees = context.signed_int(ids.fees)
        assert imbalance_fees + volatility_fees == fees, f'volatility fee error, expected {imbalance_fees + volatility_fees}, got {fees}'
    %}
    return ();
}

@external
func test_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    Fees.compute_fees(price=LIMIT, amount=1, long=LIMIT, short=0, liquidity=MIN_LIQUIDITY);
    Fees.compute_fees(price=1, amount=-LIMIT, long=0, short=LIMIT, liquidity=MIN_LIQUIDITY);
    return ();
}
