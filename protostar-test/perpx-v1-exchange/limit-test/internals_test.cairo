%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.constants.perpx_constants import (
    LIMIT,
    VOLATILITY_FEE_RATE_PRECISION,
    MIN_LIQUIDITY,
    LIQUIDITY_PRECISION,
)
from contracts.perpx_v1_exchange.internals import (
    _verify_length,
    _verify_instruments,
    _calculate_pnl,
    _calculate_fees,
    _calculate_exit_fees,
    _calculate_margin_requirement,
    _64x61_to_liquidity_precision,
    _divide_margin,
)
from contracts.perpx_v1_exchange.storage import storage_oracles
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const MATH64X61_LIMIT = Math64x61.BOUND;
const MATH64X61_FRACT_PART = Math64x61.FRACT_PART;

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
        context.self_address = ids.address 
        context.signed_int = utils.signed_int
    %}
    return ();
}

// TEST VERIFY LENGTH

@external
func test_verify_length_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: length = 0, instruments = (PRIME-1)/2
    %{ expect_revert() %}
    _verify_length(length=0, instruments=(PRIME - 1) / 2);
    return ();
}

@external
func test_verify_length_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: length = (PRIME-1)/2, instruments = 0
    %{ expect_revert() %}
    _verify_length(length=(PRIME - 1) / 2, instruments=0);
    return ();
}

// TEST CALCULATE PNL

@external
func setup_calculate_pnl_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=1, cost=-ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=-1, cost=-ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=ids.LIMIT, cost=-ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=-ids.LIMIT, cost=-ids.LIMIT)
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=1, cost=ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=-1, cost=ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=ids.LIMIT, cost=ids.LIMIT) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=-ids.LIMIT, cost=ids.LIMIT)
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=1, cost=0) 
        example(length=ids.INSTRUMENT_COUNT, price=ids.LIMIT, amount=-1, cost=0) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=ids.LIMIT, cost=0) 
        example(length=ids.INSTRUMENT_COUNT, price=1, amount=-ids.LIMIT, cost=0)
    %}
    return ();
}

@external
func test_calculate_pnl_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt, price: felt, amount: felt, cost: felt
) {
    alloc_locals;
    local instruments;
    %{
        ids.instruments = 2**ids.INSTRUMENT_COUNT - 1
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [ids.price], key=[2**i])
            store(context.self_address, "storage_positions", [0, ids.cost, ids.amount], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        signed_cost = context.signed_int(ids.cost)
        signed_amount = context.signed_int(ids.amount)
        pnl = ids.INSTRUMENT_COUNT * (ids.price * signed_amount - signed_cost)
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}
    return ();
}

// TEST CALCULATE FEES

@external
func test_calculate_fees_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: fees = LIMIT
    local instruments;
    %{
        ids.instruments = 2**ids.INSTRUMENT_COUNT - 1
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [ids.LIMIT, 0, 0], key=[ids.ACCOUNT, 2**i])
    %}
    let (local fees) = _calculate_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        fees = ids.LIMIT * ids.INSTRUMENT_COUNT
        calc_fees = context.signed_int(ids.fees)
        assert fees == calc_fees, f'fees error, expected {fees}, got {calc_fees}'
    %}
    return ();
}

// TEST CALCULATE FEES EXIT

@external
func setup_calculate_exit_fees_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{
        fee_rate = ids.VOLATILITY_FEE_RATE_PRECISION
        min_liq = ids.MIN_LIQUIDITY
        example(price=ids.LIMIT, amount=1, longs=1, shorts=1, liquidity=min_liq, fee_rate=fee_rate)
        example(price=ids.LIMIT, amount=-1, longs=1, shorts=1, liquidity=min_liq, fee_rate=fee_rate)
        example(price=1, amount=ids.LIMIT, longs=1, shorts=1, liquidity=min_liq, fee_rate=fee_rate)
        example(price=1, amount=-ids.LIMIT, longs=1, shorts=1, liquidity=min_liq, fee_rate=fee_rate)
    %}
    return ();
}

@external
func test_calculate_exit_fees_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, longs: felt, shorts: felt, liquidity: felt, fee_rate: felt) {
    alloc_locals;
    local instruments;
    %{ ids.instruments = 2**ids.INSTRUMENT_COUNT - 1 %}

    %{
        imbalance_fee_function = lambda p, a, l, s, n: p*a*(2*l*p + p*a - 2*s*p)//(2*n)
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [ids.price], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, ids.amount], key=[ids.ACCOUNT, 2**i])
            store(context.self_address, "storage_longs", [ids.longs], key=[2**i])
            store(context.self_address, "storage_shorts", [ids.shorts], key=[2**i])
            store(context.self_address, "storage_liquidity", [ids.liquidity], key=[2**i])
        store(context.self_address, "storage_volatility_fee_rate", [ids.fee_rate])
        fee = (1 + ids.fee_rate//ids.VOLATILITY_FEE_RATE_PRECISION) * ids.INSTRUMENT_COUNT * imbalance_fee_function(ids.LIMIT, 1, 1, 1, ids.MIN_LIQUIDITY)
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.exit_fees)
        assert fee == calc_fees, f'exit fees error, expected {fee}, got {calc_fees}'
    %}
    return ();
}

// TEST CALCULATE MARGIN REQUIREMENTS

@external
func setup_calculate_margin_requirement_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{
        # max volatility is choosen as log(1.05)**2 ~ 0.0005 which 
        # corresponds to a price variation of 5% over one second
        # k and vol are in 64x61
        frac_part = ids.MATH64X61_FRACT_PART
        vol = int(5*frac_part//1e4)
        k = 100*frac_part
        example(price=ids.LIMIT, amount=1, volatility=vol, k=k)
        example(price=ids.LIMIT, amount=-1, volatility=vol, k=k)
        example(price=1, amount=ids.LIMIT, volatility=vol, k=k)
        example(price=1, amount=-ids.LIMIT, volatility=vol, k=k)
    %}
    return ();
}

@external
func test_calculate_margin_requirement_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(price: felt, amount: felt, volatility: felt, k: felt) {
    alloc_locals;
    local instruments;
    %{
        import math
        ids.instruments = 2**ids.INSTRUMENT_COUNT - 1

        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [ids.price], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, ids.amount], key=[ids.ACCOUNT, 2**i])
            store(context.self_address, "storage_volatility", [ids.volatility], key=[2**i])
            store(context.self_address, "storage_margin_parameters", [ids.k, 0], key=[2**i])
    %}
    let (local margin_requirement) = _calculate_margin_requirement(
        owner=ACCOUNT, instruments=instruments, mult=1
    );
    %{
        price = ids.price
        amount = context.signed_int(ids.amount)
        vol = math.sqrt(ids.volatility / 2**61)
        mul = vol * ids.k / 2**61
        temp = math.exp(mul) - 1
        limit = max(temp, 1 / 100)
        price /= ids.LIQUIDITY_PRECISION
        amount /= ids.LIQUIDITY_PRECISION
        margin_requirement = price * abs(amount) * limit * ids.INSTRUMENT_COUNT

        max_error = 1.069e-7 * price * abs(amount) * ids.INSTRUMENT_COUNT * math.exp(math.floor(mul * math.log2(math.exp(1)))) 
        precision = abs(margin_requirement - ids.margin_requirement // 10**6)
        assert precision <= 2*max_error, f'margin requirement error, expected precision of {2*max_error} dollars, got {precision}'
    %}
    return ();
}

// TEST DIVIDE MARGIN

@external
func setup_divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        example(amount=ids.LIMIT) 
        example(amount=-ids.LIMIT)
    %}
    return ();
}

@external
func test_divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    local instruments;
    %{ ids.instruments = sum([2**i for i in range(10)]) %}
    let rest = _divide_margin(
        total=LIMIT * INSTRUMENT_COUNT, amount=amount, instruments=instruments, mult=1
    );
    %{
        signed_amount = context.signed_int(ids.amount)
        if signed_amount > 0:
            assert ids.rest == 0
        else:
            assert ids.rest == ids.LIMIT * ids.INSTRUMENT_COUNT
    %}
    return ();
}
