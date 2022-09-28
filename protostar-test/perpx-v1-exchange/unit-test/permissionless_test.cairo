%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.perpx_v1_exchange.permissionless import (
    add_liquidity,
    remove_liquidity,
    add_collateral,
    remove_collateral,
)
from src.openzeppelin.token.erc20.library import ERC20
from contracts.constants.perpx_constants import (
    RANGE_CHECK_BOUND,
    LIMIT,
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
)

//
// Constants
//

const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const INSTRUMENT = 1;
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
    %{
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        context.self_address = ids.address 
        max_examples(200)
    %}

    return ();
}

// TEST ADD LIQUIDITY

@external
func test_add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local address;
    local amount;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        ids.amount = ids.random % ids.LIMIT + 1
        stop_prank_callable = start_prank(ids.ACCOUNT)
    %}
    ERC20.approve(spender=address, amount=Uint256(amount, 0));

    // add liquidity
    add_liquidity(amount=amount, instrument=INSTRUMENT);

    %{
        stop_prank_callable() 
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        account_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_stake[0] == ids.amount, f'user stake amount error, expected {ids.amount}, got {user_stake[0]}'
        assert user_stake[1] == ids.amount*100, f'user stake shares error, expected {ids.amount * 100}, got {user_stake[1]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.amount, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.amount}, 0] got {account_balance}'
        assert exchange_balance == [ids.amount, 0], f'exchange balance error, expected [{ids.amount}, 0] got {exchange_balance}'
    %}

    return ();
}

// TEST REMOVE LIQUIDITY

@external
func test_remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provide_random: felt, remove_random: felt
) {
    alloc_locals;
    local address;
    local provide_amount;
    local remove_amount;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        ids.provide_amount = ids.provide_random % ids.LIMIT + 1
        ids.remove_amount = ids.remove_random % ids.provide_amount + 1
    %}
    ERC20.approve(spender=address, amount=Uint256(provide_amount, 0));

    // add liquidity
    add_liquidity(amount=provide_amount, instrument=INSTRUMENT);

    // remove the liquidity
    remove_liquidity(amount=remove_amount, instrument=INSTRUMENT);
    %{
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        diff = ids.provide_amount - ids.remove_amount
        shares = 100*(ids.provide_amount - ids.remove_amount)

        assert user_stake[0] == diff, f'user stake amount error, expected {diff}, got {user_stake[0]}'
        assert user_stake[1] == shares, f'user stake shares error, expected {shares}, got {user_stake[1]}'
    %}

    return ();
}

// TEST ADD COLLATERAL

@external
func test_add_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local address;
    local amount;
    %{ ids.address = context.self_address %}

    // prank the approval and the add collateral calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        ids.amount = ids.random % ids.LIMIT + 1
    %}
    ERC20.approve(spender=address, amount=Uint256(amount, 0));
    add_collateral(amount=amount);

    %{
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])
        account_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_collateral[0] == ids.amount, f'user collateral error, expected {ids.amount}, got {user_collateral[0]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND - 1 - ids.amount, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.amount}, 0] got {account_balance}'
        assert exchange_balance == [ids.amount, 0], f'exchange balance error, expected [{ids.amount}, 0] got {exchange_balance}'
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

    // prank the approval and the add liquidity calls
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
    remove_collateral(amount=remove_amount);
    %{
        stop_prank_callable() 
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])[0]
        new_collateral = ids.provide_amount - ids.remove_amount
        assert user_collateral == new_collateral, f'collateral error, expected {new_collateral}, got {user_collateral}'
    %}
    return ();
}
