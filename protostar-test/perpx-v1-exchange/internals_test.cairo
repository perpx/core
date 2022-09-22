%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address

from contracts.constants.perpx_constants import (
    RANGE_CHECK_BOUND,
    LIMIT,
    VOLATILITY_FEE_RATE_PRECISION,
    MIN_LIQUIDITY,
)
from contracts.perpx_v1_exchange.internals import (
    _verify_length,
    _verify_instruments,
    _calculate_pnl,
    _calculate_fees,
    _calculate_exit_fees,
    storage_oracles,
)
from contracts.perpx_v1_exchange.storage import storage_instrument_count
from contracts.perpx_v1_instrument import storage_longs, storage_shorts
from contracts.library.position import storage_positions
from contracts.library.vault import storage_liquidity
from contracts.library.fees import Fees, storage_volatility_fee_rate
from helpers.helpers import setup_helpers

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
    setup_helpers();
    let (local address) = get_contract_address();
    %{
        context.self_address = ids.address
        max_examples(200)
    %}
    return ();
}

@external
func test_verify_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local instruments;
    local length;
    %{
        assume(ids.random !=0)
        from random import randint, sample, seed
        seed(ids.random)
        # generate random length and according instruments value
        length = ids.random % (ids.INSTRUMENT_COUNT - 1) + 1
        instruments = sum([2**x for x in sample(range(ids.INSTRUMENT_COUNT), length)])
        # add random value to this length
        ids.length = length + randint(1, length) * [-1,1][randint(0, 1)]
        ids.instruments = instruments
    %}

    %{
        # expect all the calls to revert since length != instruments
        expect_revert()
    %}
    _verify_length(length=length, instruments=instruments);
    return ();
}

@external
func test_verify_length_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: length = 0, instruments = (PRIME-1)/2
    %{ expect_revert() %}
    _verify_length(length=0, instruments=(PRIME - 1) / 2);
    // test case: length = (PRIME-1)/2, instruments = 0
    %{ expect_revert() %}
    _verify_length(length=(PRIME - 1) / 2, instruments=0);
    return ();
}

@external
func test_verify_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local instruments;
    %{
        assume(ids.random !=0)
        from random import randint, sample, seed
        seed(ids.random)
        # generate random instruments and store the instrument count
        ids.instruments = randint(1, 2**(ids.INSTRUMENT_COUNT+1))
        store(context.self_address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
        if ids.instruments > 2**ids.INSTRUMENT_COUNT:
            expect_revert(error_message="instruments limited to 2**instrument_count")
    %}
    _verify_instruments(instruments=instruments);
    return ();
}

@external
func test_verify_instruments_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    local instruments;
    // test case: instruments=2**ids.instrument_count
    %{
        ids.instruments = 2**ids.INSTRUMENT_COUNT
        store(context.self_address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
        expect_revert(error_message="instruments limited to 2**instrument_count - 1")
    %}
    _verify_instruments(instruments=instruments);
    return ();
}

@external
func est_calculate_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample, seed
        seed(ids.random)
        length = ids.random % (ids.INSTRUMENT_COUNT - 1) + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        ids.instruments = sum([2**x for x in sample_instruments])

        prices = [randint(1, ids.LIMIT) for i in range(length)]
        amounts = [randint(-ids.LIMIT//prices[i], ids.LIMIT//prices[i]) for i in range(length)]
        costs = [randint(-ids.LIMIT, ids.LIMIT) for i in range(length)]
        pnl = sum([prices[i]*amounts[i] - costs[i] for i in range(len(prices))])

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

@external
func test_calculate_pnl_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: price = LIMIT, amount = 1, cost = 0
    local instruments;
    %{
        ids.instruments = 2**ids.INSTRUMENT_COUNT - 1
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [ids.LIMIT], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, 1], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        pnl = ids.INSTRUMENT_COUNT * ids.LIMIT
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}

    // test case: price = LIMIT, amount = -1, cost = 0
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [0, 0, -1], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        pnl = -pnl
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}

    // test case: price = 1, amount = LIMIT, cost = 0
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [1], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, ids.LIMIT], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        pnl = -pnl
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}

    // test case: price = 1, amount = -LIMIT, cost = 0
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [0, 0, -ids.LIMIT], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        pnl = -pnl
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}

    // test case: price = 0, amount = 0, cost = LIMIT
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [0], key=[2**i])
            store(context.self_address, "storage_positions", [0, ids.LIMIT, 0], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}

    // test case: price = 0, amount = 0, cost = -LIMIT
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [0, -ids.LIMIT, 0], key=[ids.ACCOUNT, 2**i])
    %}
    let (local pnl) = _calculate_pnl(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        pnl = -pnl
        calc_pnl = context.signed_int(ids.pnl)
        assert pnl == calc_pnl, f'pnl error, expected {pnl}, got {calc_pnl}'
    %}
    return ();
}

@external
func test_calculate_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample, seed
        seed(ids.random)
        length = ids.random % (ids.INSTRUMENT_COUNT - 1) + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        ids.instruments = sum([2**x for x in sample_instruments])
        fees = [randint(-ids.LIMIT, ids.LIMIT) for i in range(length)]
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

@external
func test_calculate_exit_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local instruments;
    %{
        from random import randint, sample, seed
        seed(ids.random)
        length = ids.random % (ids.INSTRUMENT_COUNT - 1) + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        ids.instruments = sum([2**x for x in sample_instruments])

        prices = [randint(1, ids.LIMIT) for i in range(length)]
        amounts = [randint(-ids.LIMIT//prices[i], ids.LIMIT//prices[i]) for i in range(length)]
        longs = [randint(1, ids.LIMIT//prices[i]) for i in range(length)]
        shorts = [randint(1, ids.LIMIT//prices[i]) for i in range(length)]
        liquidity = [randint(1e6, ids.LIMIT) for i in range(length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        imbalance_fee_function = lambda p, a, l, s, n: p*a*(2*l*p + p*a - 2*s*p)//(2*n)
        imbalance_exit_fees = [imbalance_fee_function(prices[i], -amounts[i], longs[i], shorts[i], liquidity[i]) for i in range(len(prices))]
        volatility_exit_fees = [abs(x) * fee_rate // ids.VOLATILITY_FEE_RATE_PRECISION for x in imbalance_exit_fees]
        exit_fees = sum(imbalance_exit_fees) + sum(volatility_exit_fees)

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

@external
func test_calculate_exit_fees_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    local instruments;
    %{ ids.instruments = 2**ids.INSTRUMENT_COUNT - 1 %}

    // test case: price = LIMIT, amount = 1, longs = 1, shorts = 1, liquity = 1e6, fee_rate = 10000
    %{
        imbalance_fee_function = lambda p, a, l, s, n: p*a*(2*l*p + p*a - 2*s*p)//(2*n)
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [ids.LIMIT], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, 1], key=[ids.ACCOUNT, 2**i])
            store(context.self_address, "storage_longs", [1], key=[2**i])
            store(context.self_address, "storage_shorts", [1], key=[2**i])
            store(context.self_address, "storage_liquidity", [ids.MIN_LIQUIDITY], key=[2**i])
        store(context.self_address, "storage_volatility_fee_rate", [ids.VOLATILITY_FEE_RATE_PRECISION])
        fee = 2 * ids.INSTRUMENT_COUNT * imbalance_fee_function(ids.LIMIT, 1, 1, 1, ids.MIN_LIQUIDITY)
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.exit_fees)
        assert fee == calc_fees, f'exit fees error, expected {fee}, got {calc_fees}'
    %}

    // test case: price = LIMIT, amount = -1, longs = 1, shorts = 1, liquity = 1e6, fee_rate = 10000
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [0, 0, -1], key=[ids.ACCOUNT, 2**i])
        fee = 2 * ids.INSTRUMENT_COUNT * imbalance_fee_function(ids.LIMIT, -1, 1, 1, ids.MIN_LIQUIDITY)
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.exit_fees)
        assert fee == calc_fees, f'exit fees error, expected {fee}, got {calc_fees}'
    %}

    // test case: price = 1, amount = LIMIT, longs = LIMIT, shorts = LIMIT, liquity = 1e6, fee_rate = 10000
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_oracles", [1], key=[2**i])
            store(context.self_address, "storage_positions", [0, 0, ids.LIMIT], key=[ids.ACCOUNT, 2**i])
            store(context.self_address, "storage_longs", [ids.LIMIT], key=[2**i])
            store(context.self_address, "storage_shorts", [ids.LIMIT], key=[2**i])
            store(context.self_address, "storage_liquidity", [ids.MIN_LIQUIDITY], key=[2**i])
        fee = 2 * ids.INSTRUMENT_COUNT * imbalance_fee_function(1, ids.LIMIT, ids.LIMIT, ids.LIMIT, ids.MIN_LIQUIDITY)
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.exit_fees)
        assert fee == calc_fees, f'exit fees error, expected {fee}, got {calc_fees}'
    %}

    // test case: price = 1, amount = -LIMIT, longs = LIMIT, shorts = LIMIT, liquity = 1e6, fee_rate = 10000
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_positions", [0, 0, -ids.LIMIT], key=[ids.ACCOUNT, 2**i])
        fee = 2 * ids.INSTRUMENT_COUNT * imbalance_fee_function(1, -ids.LIMIT, ids.LIMIT, ids.LIMIT, ids.MIN_LIQUIDITY)
    %}
    let (local exit_fees) = _calculate_exit_fees(owner=ACCOUNT, instruments=instruments, mult=1);
    %{
        calc_fees = context.signed_int(ids.exit_fees)
        assert fee == calc_fees, f'exit fees error, expected {fee}, got {calc_fees}'
    %}
    return ();
}
