%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

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
func test_update_prev_prices_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    let (local arr: felt*) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_prev_prices(prev_prices_len=0, prev_prices=arr);
    return ();
}

// TEST UPDATE PRICES

@external
func test_update_prices_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local arr) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_prices(prices_len=0, prices=arr, instruments=0);
    return ();
}

// TEST UPDATE MARGIN PARAMETERS

@external
func test_update_margin_parameters_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let (local arr: Parameter*) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_margin_parameters(parameters_len=0, parameters=arr, instruments=0);
    return ();
}

// TEST REMOVE COLLATERAL

@external
func test_remove_collateral_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
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

        # generate random datas which will make the test fail (costs < 0, positive fees)
        prices = [randint(1, ids.LIMIT) for i in range(length)]
        fees = [randint(0, ids.LIMIT) for i in range(length)]
        costs = [randint(-ids.LIMIT, 0) for i in range(length)]
        amounts = [randint(-ids.LIMIT//prices[i], 0) for i in range(length)]
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
        assume(margin < min_margin)

        # store all variables in storage
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
        collateral = load(context.self_address, "storage_collateral", "felt", key=[ids.ACCOUNT])[0]
        assert collateral == ids.provide_amount, f'collateral error, expected {ids.provide_amount}, got {collateral}'
    %}
    return ();
}
