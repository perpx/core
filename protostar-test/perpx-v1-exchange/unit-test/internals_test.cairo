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
    _verify_instrument,
    _calculate_pnl,
    _calculate_fees,
    _calculate_exit_fees,
    _calculate_margin_requirement,
    _64x61_to_liquidity_precision,
    _divide_margin,
    _close_all_positions,
)
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
        context.signed_int = utils.signed_int
        context.calculate_exit_fees = utils.calculate_exit_fees
        context.calculate_margin_requirement = utils.calculate_margin_requirement
        context.to_felt = utils.to_felt
        context.self_address = ids.address
        store(context.self_address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
        max_examples(utils.read_max_examples("./config.yml"))
    %}
    return ();
}

// TEST VERIFY LENGTH

@external
func setup_verify_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        example(length=1)
        example(length=ids.INSTRUMENT_COUNT)
        given(
            length = strategy.integers(1, ids.INSTRUMENT_COUNT)
        )
    %}
    return ();
}

@external
func test_verify_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import sample
        # generate random instrument values
        ids.instruments = sum([2**x for x in sample(range(ids.INSTRUMENT_COUNT), ids.length)])
    %}
    _verify_length(length=length, instruments=instruments);
    return ();
}

// TEST VERIFY INSTRUMENTS

@external
func setup_verify_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        example(instruments=1)
        example(instruments=2**ids.INSTRUMENT_COUNT-1)
        given(
            instruments = strategy.integers(1, 2**ids.INSTRUMENT_COUNT-1)
        )
    %}
    return ();
}

@external
func test_verify_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instruments: felt
) {
    _verify_instruments(instruments=instruments);
    return ();
}

// TEST VERIFY INSTRUMENT

@external
func setup_verify_instrument{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        example(instrument=0)
        example(instrument=2**ids.INSTRUMENT_COUNT-1)
        given(
            instrument = strategy.integers(0, 2**ids.INSTRUMENT_COUNT-1)
        )
    %}
    return ();
}

@external
func test_verify_instrument{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) {
    %{
        import math
        if ids.instrument != 0 and not math.log2(ids.instrument).is_integer():
            expect_revert()
    %}
    _verify_instrument(instrument=instrument);
    return ();
}

// TEST CALCULATE PNL

@external
func setup_calculate_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(length=strategy.integers(0, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_calculate_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])

        prices = [randint(1, ids.LIMIT) for i in range(ids.length)]
        amounts = [randint(-ids.LIMIT//prices[i], ids.LIMIT//prices[i]) for i in range(ids.length)]
        costs = [randint(-ids.LIMIT, ids.LIMIT) for i in range(ids.length)]
        pnl = sum([prices[i]*amounts[i]//10**6 - costs[i] for i in range(ids.length)])

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [0, costs[i], amounts[i]], key=[ids.ACCOUNT, 2**bit])
    %}

    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {int(pnl)}, got {calc_pnl}'
    %}
    return ();
}

// TEST CALCULATE FEES

@external
func setup_calculate_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(length=strategy.integers(0, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_calculate_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])
        fees = [randint(-ids.LIMIT, ids.LIMIT) for i in range(ids.length)]
        fee = sum(fees)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_positions", [fees[i], 0, 0], key=[ids.ACCOUNT, 2**bit])
    %}

    let (local fees) = _calculate_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.fees)
        assert fee == calc_fees, f'fees error, expected {fee}, got {calc_fees}'
    %}
    return ();
}

// TEST CALCULATE EXIT FEES

@external
func setup_calculate_exit_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(length=strategy.integers(0, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_calculate_exit_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])

        prices = [randint(1, ids.LIMIT) for i in range(ids.length)]
        amounts = [randint(-ids.LIMIT//prices[i], ids.LIMIT//prices[i]) for i in range(ids.length)]
        longs = [randint(1, ids.LIMIT//prices[i]) for i in range(ids.length)]
        shorts = [randint(1, ids.LIMIT//prices[i]) for i in range(ids.length)]
        liquidity = [randint(1e6, ids.LIMIT) for i in range(ids.length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        exit_fees = context.calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [0, 0, amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate], key=[])
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_exit_fees = context.signed_int(ids.exit_fees)
        assert exit_fees == calc_exit_fees, f'exit fees error, expected {exit_fees}, got {calc_exit_fees}'
    %}
    return ();
}

// TEST 64x61 TO LIQUIDITY PRECISION

@external
func setup_64x61_to_liquidity_precision{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{ given(amount=strategy.integers(1, ids.MATH64X61_LIMIT)) %}
    return ();
}

@external
func test_64x61_to_liquidity_precision{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(amount: felt) {
    alloc_locals;
    %{ new_amount = ids.amount // (ids.MATH64X61_FRACT_PART // ids.LIQUIDITY_PRECISION) %}
    local val = _64x61_to_liquidity_precision(x=amount);
    %{ assert ids.val == new_amount, f'precision conversion error, expected {new_amount}, got {ids.val}' %}
    return ();
}

// TEST CALCULATE MARGIN REQUIREMENT

@external
func setup_calculate_margin_requirement{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    %{ given(length=strategy.integers(1, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_calculate_margin_requirement{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(length: felt) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample
        import numpy as np
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])

        prices = [randint(1, ids.LIMIT) for i in range(ids.length)]
        amounts = [randint(-ids.LIMIT//price, ids.LIMIT//price) for price in prices]
        volatility = [randint(1, ids.MATH64X61_FRACT_PART//(5*10**4)) for i in range(ids.length)]
        parameters = [randint(1, 100*ids.MATH64X61_FRACT_PART) for i in range(ids.length)]
        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [0, 0, amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [parameters[i], 0], key=[2**bit])
    %}
    let (local margin_requirement) = _calculate_margin_requirement(
        owner=ACCOUNT, instruments=instruments, mult=1
    );
    %{
        volatility = np.array(volatility)/2**61
        k = np.array(parameters, dtype=float)/2**61
        prices = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices, np.absolute(amounts))
        margin_factor = np.multiply(np.sqrt(volatility), k)
        margin_requirement = context.calculate_margin_requirement(volatility, k, size)
        notional_size = np.sum(size)
        precision = abs(margin_requirement - ids.margin_requirement // 10**6)
        assert precision <= 1e-5 * notional_size, f'margin requirement error, expected precision under {notional_size*1e-5} dollars, got {precision}'
    %}
    return ();
}

// TEST CLOSE ALL POSITIONS

@external
func setup_close_positions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(length=strategy.integers(1, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_close_positions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])

        sizes = [randint(-ids.LIMIT, ids.LIMIT) for i in range(ids.length)]
        fees = [randint(-ids.LIMIT, ids.LIMIT) for i in range(ids.length)]
        costs = [randint(-ids.LIMIT, ids.LIMIT) for i in range(ids.length)]
        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_positions", [fees[i], costs[i], sizes[i]], key=[ids.ACCOUNT, 2**bit])
    %}
    let (instrument_count) = _close_all_positions(
        owner=ACCOUNT, instruments=instruments, instrument_count=0, mult=1
    );
    %{
        assert ids.instrument_count == len(sample_instruments), f'instrument count error, expected {len(sample_instruments)}, got {ids.instrument_count}'
        for bit in sample_instruments:
            pos = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**bit])
            assert pos == [0, 0, 0], f'position error, expected [0, 0, 0], got {pos}'
    %}
    return ();
}

// TEST DIVIDE MARGIN

@external
func setup_divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(length=strategy.integers(1, ids.INSTRUMENT_COUNT)) %}
    return ();
}

@external
func test_divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt
) {
    alloc_locals;
    local margin;
    local total_margin;
    local instruments;
    %{
        from random import randint, sample
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), ids.length)
        ids.instruments = sum([2**x for x in sample_instruments])

        liquidity = [randint(1, ids.LIMIT)for i in range(ids.length)]
        max_liquidity = max(liquidity)
        margin = randint(-2*max_liquidity, 2*max_liquidity)
        ids.margin = context.to_felt(margin)
        ids.total_margin = ids.length * abs(margin)
        rest = ids.total_margin - sum([abs(margin) if l + margin > 0 else l for l in liquidity])
        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
    %}
    let rest = _divide_margin(total=total_margin, amount=margin, instruments=instruments, mult=1);
    %{
        rest_signed = context.signed_int(ids.rest)
        assert  rest_signed == rest, f'rest error, expected {rest}, got {rest_signed}'
        for (i, bit) in enumerate(sample_instruments):
            change = margin if liquidity[i] + margin > 0 else -liquidity[i]
            liq = context.signed_int(load(context.self_address, "storage_liquidity", "felt", key=[2**bit])[0])
            assert liq == liquidity[i] + change, f'liquidity error, expected {liquidity[i]+change}, got {liq}'
    %}

    return ();
}
