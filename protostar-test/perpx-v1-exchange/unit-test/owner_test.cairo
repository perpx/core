%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address
from starkware.cairo.common.uint256 import Uint256

from contracts.constants.perpx_constants import (
    LIMIT,
    RANGE_CHECK_BOUND,
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
)
from contracts.perpx_v1_exchange.owners import (
    update_prev_prices,
    _update_volatility,
    update_prices,
    update_margin_parameters,
    _remove_collateral,
)
from contracts.perpx_v1_exchange.permissionless import add_collateral
from contracts.perpx_v1_exchange.structures import Parameter
from src.openzeppelin.token.erc20.library import ERC20
from contracts.perpx_v1_exchange.storage import storage_instrument_count
from openzeppelin.access.ownable.library import Ownable_owner
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const MATH_PRECISION = 2 ** 64 + 2 ** 61;
const MATH64X61_FRACT_PART = 2 ** 61;
const LOW_LIMIT = 10 ** 4;

//
// Helper
//

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}
    let caller = address;
    // subtract allowance
    ERC20._spend_allowance(sender, caller, amount);
    // execute transfer
    ERC20._transfer(sender, recipient, amount);
    return ();
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    let (sender) = get_caller_address();
    ERC20._transfer(sender, recipient, amount);
    return ();
}

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    Ownable_owner.write(OWNER);
    storage_instrument_count.write(INSTRUMENT_COUNT);
    %{
        context.self_address = ids.address
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        max_examples(200)
    %}
    return ();
}

// TEST UPDATE PREV PRICES

@external
func test_update_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    let (local arr: felt*) = alloc();
    %{
        from random import randint
        prev_prices = [randint(0, ids.LIMIT) for x in range(ids.INSTRUMENT_COUNT)]
        for (i, prev) in enumerate(prev_prices):
            memory[ids.arr + i] = prev
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER) %}
    update_prev_prices(prev_prices_len=INSTRUMENT_COUNT, prev_prices=arr);
    %{
        for i in range(ids.INSTRUMENT_COUNT):
            price = load(context.self_address, "storage_prev_oracles", "felt", key=[2**i])[0]
            assert prev_prices[i] == price, f'previous prices error, expected {prev_prices[i]}, got {price}'
    %}
    return ();
}

// TEST UPDATE VOLATILITY

@external
func test_update_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    %{
        from random import seed,randint, random
        import importlib  
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.random)
        prev_prices = [randint(1, ids.LIMIT) for x in range(ids.INSTRUMENT_COUNT)]
        prices = [randint(1, ids.LIMIT) for x in range(ids.INSTRUMENT_COUNT)]
        lambdas = [randint(0, ids.MATH_PRECISION) for x in range(ids.INSTRUMENT_COUNT)]
        prev_vols = [randint(0, ids.LIMIT) for x in range(ids.INSTRUMENT_COUNT)]
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.self_address, "storage_prev_oracles", [prev_prices[i]], key=[2**i])
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**i])
            store(context.self_address, "storage_volatility", [prev_vols[i]], key=[2**i])
            store(context.self_address, "storage_margin_parameters", [0, lambdas[i]], key=[2**i])
    %}
    _update_volatility(instrument_count=INSTRUMENT_COUNT, mult=1);
    %{
        import math
        returns = [math.pow(math.log10(x/y), 2) * 2**61 for (x, y) in zip(prices, prev_prices)]
        vol = [utils.mul(x, y) + ret for (x,y,ret) in zip(lambdas, prev_vols, returns)]
        for i in range(ids.INSTRUMENT_COUNT):
            volatility = load(context.self_address, "storage_volatility", "felt", key=[2**i])[0]
            diff = abs(vol[i] - volatility) / 2**61
            assert diff < 1e-6, f'volatility error, expected error to be less than 1e-6, got {diff}'
    %}
    return ();
}

// TEST UPDATE PRICES AND MARGIN REQUIREMENTS

@external
func test_updates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(random: felt) {
    alloc_locals;
    let (local arr_prices) = alloc();
    let (local arr_parameters: Parameter*) = alloc();
    local instruments;
    local length;
    %{
        #init the parameters, instruments and prices
        from random import randint, sample
        ids.length = ids.random % ids.INSTRUMENT_COUNT + 1
        instruments = [2**x for x in sample(range(ids.INSTRUMENT_COUNT), ids.length)]
        instruments.sort()
        ids.instruments = sum(instruments)
        last_prices = [randint(0, ids.LIMIT) for x in range(ids.INSTRUMENT_COUNT)]

        for i in range(ids.length):
            x = memory[ids.arr_prices + i] = randint(0, ids.LIMIT)
            memory[ids.arr_parameters._reference_value + 2*i] = randint(0, ids.MATH_PRECISION)
            memory[ids.arr_parameters._reference_value + 2*i + 1] = randint(0, ids.MATH_PRECISION)
        for (bit, price) in enumerate(last_prices):
            store(context.self_address, "storage_oracles", [price], key=[2**bit])
    %}
    // prank and call functions
    %{ stop_prank_callable = start_prank(ids.OWNER) %}
    update_prices(prices_len=length, prices=arr_prices, instruments=instruments);
    update_margin_parameters(
        parameters_len=length, parameters=arr_parameters, instruments=instruments
    );
    %{
        # check prices, parameters and previous prices were updated
        stop_prank_callable() 
        for (i, bit) in enumerate(instruments):
            price = load(context.self_address, "storage_oracles", "felt", key=[bit])[0]
            parameter = load(context.self_address, "storage_margin_parameters", "Parameter", key=[bit])
            assert price == memory[ids.arr_prices + i], f'instrument price error got {price}, expected {memory[ids.arr_prices + i]}'
            assert parameter[0] == memory[ids.arr_parameters._reference_value + 2*i], f'instrument parameter error got {parameter[0]}, expected {memory[ids.arr_parameters._reference_value + 2*i]}'
            assert parameter[1] == memory[ids.arr_parameters._reference_value + 2*i +1], f'instrument parameter error got {parameter[1]}, expected {memory[ids.arr_parameters._reference_value + 2*i + 1]}'

        for i in range(ids.INSTRUMENT_COUNT):
            price = load(context.self_address, "storage_prev_oracles", "felt", key=[2**i])[0]
            assert last_prices[i] == price, f'last price error, expected {last_prices[i]}, got {price}'
    %}
    return ();
}

@external
func test_remove_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provide_random: felt, remove_random: felt
) {
    alloc_locals;
    local address;
    local provide_amount;
    local remove_amount;
    %{ ids.address = context.self_address %}

    // prank the approval and the add collateral calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        ids.provide_amount = ids.provide_random % ids.LIMIT + 1
        ids.remove_amount = ids.remove_random % ids.provide_amount + 1
    %}
    ERC20.approve(spender=address, amount=Uint256(provide_amount, 0));
    add_collateral(amount=provide_amount);

    // create fake positions for the user
    %{
        from random import randint, sample, seed
        import importlib  
        import numpy as np
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.provide_amount)
        length = ids.provide_amount % ids.INSTRUMENT_COUNT + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        instruments = sum([2**i for i in sample_instruments]) 

        # generate random datas which will make the test pass (costs = 0, negative fees)
        prices = [randint(1, ids.LIMIT) for i in range(length)]
        fees = [randint(-ids.LIMIT, 0) for i in range(length)]
        amounts = [randint(0, ids.LIMIT//prices[i]) for i in range(length)]
        volatility = [randint(1, ids.MATH64X61_FRACT_PART//(5*10**4)) for i in range(length)]
        k = [randint(1, 100*ids.MATH64X61_FRACT_PART) for i in range(length)]
        longs = [randint(1, ids.LIMIT//prices[i]) for i in range(length)]
        shorts = [randint(1, ids.LIMIT//prices[i]) for i in range(length)]
        liquidity = [randint(1e6, ids.LIMIT) for i in range(length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        # calculate the owners margin
        f = sum(fees)
        exit_fees = utils.calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)
        pnl = sum([p*a for (p,a) in zip(prices, amounts)])
        margin = ids.provide_amount - ids.remove_amount + pnl - f - exit_fees

        # calculate the minimum margin for the instruments owner
        v_scaled = np.array(volatility)/2**61
        k_scaled = np.array(k, dtype=float)/2**61
        prices_scaled = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts_scaled = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices_scaled, np.absolute(amounts_scaled))
        min_margin = utils.calculate_margin_requirement(v_scaled, k_scaled, size) * ids.LIQUIDITY_PRECISION
        assume(margin > min_margin)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [fees[i], 0, amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [k[i], 0], key=[2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [instruments], key=[ids.ACCOUNT])
    %}

    // remove the collateral
    _remove_collateral(caller=ACCOUNT, amount=remove_amount);
    %{
        stop_prank_callable() 
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])[0]
        new_collateral = ids.provide_amount - ids.remove_amount
        assert user_collateral == new_collateral, f'collateral error, expected {new_collateral}, got {user_collateral}'
    %}
    return ();
}
