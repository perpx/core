%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import LIMIT, MIN_LIQUIDITY
from contracts.test.helpers import setup_helpers

@contract_interface
namespace TestContract {
    func compute_imbalance_fee_test(
        price: felt, amount: felt, long: felt, short: felt, liquidity: felt
    ) -> (res: felt) {
    }
    func compute_fees_test(price: felt, amount: felt, long: felt, short: felt, liquidity: felt) -> (
        res: felt
    ) {
    }
}

//
// Setup
//

@external
func __setup__() {
    setup_helpers();
    %{ context.contract_address = deploy_contract("./contracts/test/fees_test.cairo").contract_address %}
    %{ max_examples(200) %}
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
    local liquidity;
    local address;
    %{
        assume(ids.short < ids.LIMIT and ids.long < ids.LIMIT and abs(ids.price*ids.amount) < ids.LIMIT)
        amount = context.signed_int(ids.amount)
        from random import randint
        volatility_fee_rate = randint(0, 10000)
        store(context.contract_address, "storage_volatility_fee_rate", [volatility_fee_rate], key=[])
        ids.liquidity = ids.MIN_LIQUIDITY
        ids.address = context.contract_address
    %}
    let (local imbalance_fees) = TestContract.compute_imbalance_fee_test(
        contract_address=address,
        price=price,
        amount=amount,
        long=long,
        short=short,
        liquidity=liquidity,
    );
    let (local fees) = TestContract.compute_fees_test(
        contract_address=address,
        price=price,
        amount=amount,
        long=long,
        short=short,
        liquidity=liquidity,
    );
    %{
        nom = ids.price * amount * (2*ids.long + ids.price * amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        volatility_fee = (abs(imbalance_fees) * volatility_fee_rate) // 10**4

        imbalance = context.signed_int(ids.imbalance_fees)
        assert imbalance == imbalance_fees, f'imbalance fees error, expected {imbalance_fees}, got {imbalance}'
        fees = context.signed_int(ids.fees)
        assert imbalance_fees + volatility_fee == fees, f'fees error, expected {imbalance_fees + volatility_fee}, got {fees}'
    %}
    return ();
}

@external
func test_longs_shorts_compute_fees_fees{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, liquidity: felt) {
    alloc_locals;
    local long = LIMIT;
    local short = LIMIT;
    local liq;
    local address;
    %{
        assume(abs(ids.price*ids.amount) < ids.LIMIT)
        amount = context.signed_int(ids.amount)

        from random import randint
        volatility_fee_rate = randint(0, 10000)
        store(context.contract_address, "storage_volatility_fee_rate", [volatility_fee_rate], key=[])

        mod = ids.liquidity % (ids.LIMIT - 1) + 1
        ids.liq = mod if mod > ids.MIN_LIQUIDITY else mod + ids.MIN_LIQUIDITY

        price = ids.price
        long = ids.LIMIT
        short = 0
        nom = price * amount * (2 * long + price * amount - 2 * short)
        denom = 2 * ids.liq
        ids.address = context.contract_address
    %}
    // compute fees
    let (local imbalance_fees) = TestContract.compute_imbalance_fee_test(
        contract_address=address, price=price, amount=amount, long=long, short=0, liquidity=liq
    );
    let (local fees) = TestContract.compute_fees_test(
        contract_address=address, price=price, amount=amount, long=long, short=0, liquidity=liq
    );
    %{
        imbalance = context.signed_int(ids.imbalance_fees)
        imbalance_fees = nom // denom
        volatility_fees = abs(imbalance_fees) * volatility_fee_rate // 10**4
        fees = context.signed_int(ids.fees)

        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
        assert imbalance_fees + volatility_fees == fees, f'volatility fee error, expected {imbalance_fees + volatility_fees}, got {fees}'
    %}
    %{
        long = 0
        short = ids.LIMIT
        nom = price * amount * (2 * long + price * amount - 2 * short)
        denom = 2 * ids.liq
    %}
    // compute fees
    let (local imbalance_fees) = TestContract.compute_imbalance_fee_test(
        contract_address=address, price=price, amount=amount, long=0, short=short, liquidity=liq
    );
    let (local fees) = TestContract.compute_fees_test(
        contract_address=address, price=price, amount=amount, long=0, short=short, liquidity=liq
    );
    %{
        imbalance = context.signed_int(ids.imbalance_fees)
        imbalance_fees = nom // denom
        volatility_fees = abs(imbalance_fees) * volatility_fee_rate // 10**4
        fees = context.signed_int(ids.fees)

        assert imbalance == imbalance_fees, f'imbalance fee error, expected {imbalance_fees}, got {imbalance}'
        assert imbalance_fees + volatility_fees == fees, f'volatility fee error, expected {imbalance_fees + volatility_fees}, got {fees}'
    %}
    return ();
}

@external
func test_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    %{ ids.address = context.contract_address %}
    let (local fees) = TestContract.compute_fees_test(
        contract_address=address,
        price=LIMIT,
        amount=1,
        long=LIMIT,
        short=0,
        liquidity=MIN_LIQUIDITY,
    );
    let (local fees) = TestContract.compute_fees_test(
        contract_address=address,
        price=1,
        amount=-LIMIT,
        long=0,
        short=LIMIT,
        liquidity=MIN_LIQUIDITY,
    );
    return ();
}
