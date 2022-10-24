%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.library.fees import Fees, storage_volatility_fee_rate
from contracts.constants.perpx_constants import LIMIT, MIN_LIQUIDITY
from helpers.helpers import setup_helpers

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    setup_helpers();
    %{
        max_examples(200) 
        context.self_address = ids.address
    %}
    return ();
}

//
// Tests
//

@external
func test_liquidity_compute_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, amount: felt, long: felt, short: felt
) -> () {
    alloc_locals;
    %{
        # assumed limits when computing the fees
        assume(ids.short < ids.LIMIT and ids.long < ids.LIMIT and abs(ids.price*ids.amount) < ids.LIMIT)
        from random import randint
        volatility_fee_rate = randint(0, 10000)
        store(context.self_address, "storage_volatility_fee_rate", [volatility_fee_rate], key=[])
    %}
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=MIN_LIQUIDITY
    );
    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=MIN_LIQUIDITY
    );
    %{
        amount = context.signed_int(ids.amount)
        imbalance_fees = ids.price * amount * (2*ids.long + ids.price * amount - 2* ids.short) // 10**12 // (2 * ids.MIN_LIQUIDITY)
        volatility_fee = (abs(imbalance_fees) * volatility_fee_rate) // 10**4

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fees error, expected {imbalance_fees}, got {imbalance}'

        fees = context.signed_int(ids.fees)
        assert imbalance_fees + volatility_fee == fees, f'fees error, expected {imbalance_fees + volatility_fee}, got {fees}'
    %}
    return ();
}

@external
func test_longs_shorts_compute_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, liq: felt) {
    alloc_locals;
    local liquidity;
    %{
        assume(abs(ids.price*ids.amount) < ids.LIMIT)

        amount = context.signed_int(ids.amount)
        from random import randint
        volatility_fee_rate = randint(0, 10000)
        store(context.self_address, "storage_volatility_fee_rate", [volatility_fee_rate], key=[])

        ids.liquidity = ids.liq % (ids.LIMIT - ids.MIN_LIQUIDITY) + ids.MIN_LIQUIDITY
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
        volatility_fees = abs(imbalance_fees) * volatility_fee_rate // 10**4

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
        volatility_fees = abs(imbalance_fees) * volatility_fee_rate // 10**4

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
