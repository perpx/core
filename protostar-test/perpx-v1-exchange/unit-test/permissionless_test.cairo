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
    liquidate,
)
from src.openzeppelin.token.erc20.library import ERC20
from contracts.constants.perpx_constants import (
    RANGE_CHECK_BOUND,
    LIMIT,
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
    MAX_LIQUIDATOR_PAY_OUT,
    MIN_LIQUIDATOR_PAY_OUT,
)

//
// Constants
//

const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const INSTRUMENT = 1;
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
    local amount_1;
    local amount_2;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        ids.amount_1 = ids.random % (ids.LIMIT//100) + 1
        ids.amount_2 = ids.random % (ids.LIMIT//100 - ids.amount_1) + 1
        start_prank(ids.ACCOUNT)
    %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT, 0));

    // add liquidity
    add_liquidity(amount=amount_1, instrument=INSTRUMENT);

    %{
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        account_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_stake[0] == ids.amount_1*100, f'user stake shares error, expected {ids.amount_1 * 100}, got {user_stake[0]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.amount_1, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.amount_1}, 0] got {account_balance}'
        assert exchange_balance == [ids.amount_1, 0], f'exchange balance error, expected [{ids.amount_1}, 0] got {exchange_balance}'
    %}

    // add liquidity
    add_liquidity(amount=amount_2, instrument=INSTRUMENT);
    %{
        stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])

        assert stake[0] == user_stake[0] + ids.amount_2*user_stake[0]//ids.amount_1, f'user stake shares error, expected {user_stake[0] + ids.amount_2*user_stake[0]//ids.amount_1}, got {stake[0]}'
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
        ids.provide_amount = ids.provide_random % (ids.LIMIT//100) + 1
        ids.remove_amount = ids.remove_random % ids.provide_amount + 1
    %}
    ERC20.approve(spender=address, amount=Uint256(provide_amount, 0));

    // add liquidity
    add_liquidity(amount=provide_amount, instrument=INSTRUMENT);

    // remove the liquidity
    remove_liquidity(amount=remove_amount, instrument=INSTRUMENT);
    %{
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        shares = 100*(ids.provide_amount - ids.remove_amount) # share change = initial shares - remove shares = 100*provide - remove*100*provide/provide

        assert user_stake[0] == shares, f'user stake shares error, expected {shares}, got {user_stake[0]}'
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
    remove_collateral(amount=remove_amount);
    %{
        stop_prank_callable() 
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])[0]
        new_collateral = ids.provide_amount - ids.remove_amount
        assert user_collateral == new_collateral, f'collateral error, expected {new_collateral}, got {user_collateral}'
    %}
    return ();
}

@external
func test_liquidate_negative_margin{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(random: felt) {
    alloc_locals;
    local address;
    local collateral;
    // prank the approval and the add collateral calls
    %{
        ids.address = context.self_address
        start_prank(ids.ACCOUNT)
        ids.collateral = ids.random % ids.LIMIT + 1
    %}
    ERC20.approve(spender=address, amount=Uint256(collateral, 0));
    add_collateral(amount=collateral);

    // create fake positions for the user
    %{
        from random import randint, sample, seed
        import importlib  
        import numpy as np
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.collateral)
        length = ids.collateral % ids.INSTRUMENT_COUNT + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        instruments = sum([2**i for i in sample_instruments]) 

        # generate random datas which will make the test pass 
        prices = [randint(1, ids.LIMIT) for i in range(length)]
        fees = [randint(0, ids.LIMIT) for i in range(length)]
        costs = [randint(0, ids.LIMIT) for i in range(length)]
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
        pnl = sum([p*a-c for (p,a,c) in zip(prices, amounts, costs)])
        margin = ids.collateral + pnl - f - exit_fees

        # calculate the minimum margin for the instruments owner
        v_scaled = np.array(volatility)/2**61
        k_scaled = np.array(k, dtype=float)/2**61
        prices_scaled = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts_scaled = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices_scaled, np.absolute(amounts_scaled))
        min_margin = utils.calculate_margin_requirement(v_scaled, k_scaled, size) * ids.LIQUIDITY_PRECISION
        assume(margin < 0 and margin < min_margin)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [fees[i], costs[i], amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [k[i], 0], key=[2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [instruments], key=[ids.ACCOUNT])
        expect_events({"name": "Liquidate", "data": [ids.ACCOUNT, instruments]})
    %}
    liquidate(owner=ACCOUNT);
    %{
        liquidity_change = margin//length
        for (i, bit) in enumerate(sample_instruments):
            position = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**bit])
            new_liquidity = utils.signed_int(load(context.self_address, "storage_liquidity", "felt", key=[2**bit])[0])
            assert position == [0, 0, 0], f'position error, expected [0, 0, 0], got {position}'
            assert liquidity[i] + liquidity_change == new_liquidity, f'liquidity error, expected {liquidity[i] + liquidity_change}, got {new_liquidity}'
    %}
    return ();
}

@external
func test_liquidate_positive_min_payout{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(random: felt) {
    alloc_locals;
    local address;
    local collateral;

    // create fake positions for the user
    %{
        from random import randint, sample, seed
        import importlib  
        import numpy as np
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.random)
        length = ids.random % ids.INSTRUMENT_COUNT + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        instruments = sum([2**i for i in sample_instruments]) 

        # generate random datas which will make the test pass 
        factor = 100
        prices = [factor*ids.MIN_LIQUIDATOR_PAY_OUT//length for i in range(length)]
        amounts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        fees = [factor//2 * ids.MIN_LIQUIDATOR_PAY_OUT * ids.LIQUIDITY_PRECISION for i in range(length)]
        costs = [factor//2 * ids.MIN_LIQUIDATOR_PAY_OUT * ids.LIQUIDITY_PRECISION for i in range(length)]
        volatility = [randint(1, ids.MATH64X61_FRACT_PART // (5*10**4)) for i in range(length)]
        k = [randint(1, 100*ids.MATH64X61_FRACT_PART) for i in range(length)]
        longs = [ids.LIQUIDITY_PRECISION for i in range(length)]
        shorts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        liquidity = [ids.LIMIT for i in range(length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        # calculate the owners margin
        f = sum(fees)
        exit_fees = utils.calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)
        pnl = sum([p*a-c for (p,a,c) in zip(prices, amounts, costs)])
        margin = pnl - f - exit_fees

        # calculate the minimum margin for the instruments owner
        v_scaled = np.array(volatility)/2**61
        k_scaled = np.array(k, dtype=float)/2**61
        prices_scaled = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts_scaled = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices_scaled, np.absolute(amounts_scaled))
        min_margin = utils.calculate_margin_requirement(v_scaled, k_scaled, size) * ids.LIQUIDITY_PRECISION
    %}
    // prank the approval and the add collateral calls
    %{
        ids.address = context.self_address
        start_prank(ids.ACCOUNT)
        collateral = ids.MIN_LIQUIDATOR_PAY_OUT - 1 - margin
        ids.collateral = collateral if collateral > 0 else PRIME - collateral
        margin = ids.collateral + margin
    %}
    ERC20.approve(spender=address, amount=Uint256(collateral, 0));
    add_collateral(amount=collateral);

    %{
        assume(margin < min_margin and 0 < margin < ids.MIN_LIQUIDATOR_PAY_OUT)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [fees[i], costs[i], amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [k[i], 0], key=[2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [instruments], key=[ids.ACCOUNT])
        expect_events({"name": "Liquidate", "data": [ids.ACCOUNT, instruments]})
    %}

    liquidate(owner=ACCOUNT);
    %{
        liquidity_change = (ids.MIN_LIQUIDATOR_PAY_OUT - margin)//length
        for (i, bit) in enumerate(sample_instruments):
            position = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**bit])
            new_liquidity = utils.signed_int(load(context.self_address, "storage_liquidity", "felt", key=[2**bit])[0])
            assert position == [0, 0, 0], f'position error, expected [0, 0, 0], got {position}'
            assert liquidity[i] - liquidity_change == new_liquidity, f'liquidity error, expected {liquidity[i] + liquidity_change}, got {new_liquidity}'
    %}
    return ();
}

@external
func test_liquidate_positive_min_max_payout{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(random: felt) {
    alloc_locals;
    local address;
    local collateral;

    // create fake positions for the user
    %{
        from random import randint, sample, seed
        import importlib  
        import numpy as np
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.random)
        length = ids.random % ids.INSTRUMENT_COUNT + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        instruments = sum([2**i for i in sample_instruments]) 

        # generate random datas which will make the test pass 
        factor = 100
        mean = (ids.MAX_LIQUIDATOR_PAY_OUT - ids.MIN_LIQUIDATOR_PAY_OUT)//2
        prices = [factor*mean//length for i in range(length)]
        amounts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        fees = [factor//2 * mean * ids.LIQUIDITY_PRECISION for i in range(length)]
        costs = [factor//2 * mean * ids.LIQUIDITY_PRECISION for i in range(length)]
        volatility = [randint(1, ids.MATH64X61_FRACT_PART // (5*10**4)) for i in range(length)]
        k = [randint(1, 100*ids.MATH64X61_FRACT_PART) for i in range(length)]
        longs = [ids.LIQUIDITY_PRECISION for i in range(length)]
        shorts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        liquidity = [ids.LIMIT for i in range(length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        # calculate the owners margin
        f = sum(fees)
        exit_fees = utils.calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)
        pnl = sum([p*a-c for (p,a,c) in zip(prices, amounts, costs)])
        margin = pnl - f - exit_fees

        # calculate the minimum margin for the instruments owner
        v_scaled = np.array(volatility)/2**61
        k_scaled = np.array(k, dtype=float)/2**61
        prices_scaled = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts_scaled = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices_scaled, np.absolute(amounts_scaled))
        min_margin = utils.calculate_margin_requirement(v_scaled, k_scaled, size) * ids.LIQUIDITY_PRECISION
    %}
    // prank the approval and the add collateral calls
    %{
        ids.address = context.self_address
        start_prank(ids.ACCOUNT)
        ids.collateral = mean - 1 - margin
        margin = ids.collateral + margin
    %}
    ERC20.approve(spender=address, amount=Uint256(collateral, 0));
    add_collateral(amount=collateral);

    %{
        assume(margin < min_margin and ids.MIN_LIQUIDATOR_PAY_OUT < margin < ids.MAX_LIQUIDATOR_PAY_OUT)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [fees[i], costs[i], amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [k[i], 0], key=[2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [instruments], key=[ids.ACCOUNT])
        expect_events({"name": "Liquidate", "data": [ids.ACCOUNT, instruments]})
    %}

    liquidate(owner=ACCOUNT);
    %{
        for (i, bit) in enumerate(sample_instruments):
            position = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**bit])
            new_liquidity = utils.signed_int(load(context.self_address, "storage_liquidity", "felt", key=[2**bit])[0])
            assert position == [0, 0, 0], f'position error, expected [0, 0, 0], got {position}'
            assert liquidity[i] == new_liquidity, f'liquidity error, expected {liquidity[i]}, got {new_liquidity}'
    %}
    return ();
}

@external
func test_liquidate_positive_max_payout{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(random: felt) {
    alloc_locals;
    local address;
    local collateral;

    // create fake positions for the user
    %{
        from random import randint, sample, seed
        import importlib  
        import numpy as np
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(ids.random)
        length = ids.random % ids.INSTRUMENT_COUNT + 1
        sample_instruments = sample(range(0, ids.INSTRUMENT_COUNT), length)
        instruments = sum([2**i for i in sample_instruments]) 

        # generate random datas which will make the test pass 
        factor = 100
        prices = [factor*ids.MAX_LIQUIDATOR_PAY_OUT//length for i in range(length)]
        amounts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        fees = [factor//2 * ids.MAX_LIQUIDATOR_PAY_OUT * ids.LIQUIDITY_PRECISION for i in range(length)]
        costs = [factor//2 * ids.MAX_LIQUIDATOR_PAY_OUT * ids.LIQUIDITY_PRECISION for i in range(length)]
        volatility = [randint(1, ids.MATH64X61_FRACT_PART // (5*10**4)) for i in range(length)]
        k = [randint(1, 100*ids.MATH64X61_FRACT_PART) for i in range(length)]
        longs = [ids.LIQUIDITY_PRECISION for i in range(length)]
        shorts = [ids.LIQUIDITY_PRECISION for i in range(length)]
        liquidity = [ids.LIMIT for i in range(length)]
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        # calculate the owners margin
        f = sum(fees)
        exit_fees = utils.calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)
        pnl = sum([p*a-c for (p,a,c) in zip(prices, amounts, costs)])
        margin = pnl - f - exit_fees

        # calculate the minimum margin for the instruments owner
        v_scaled = np.array(volatility)/2**61
        k_scaled = np.array(k, dtype=float)/2**61
        prices_scaled = np.array(prices)/ids.LIQUIDITY_PRECISION
        amounts_scaled = np.array(amounts)/ids.LIQUIDITY_PRECISION
        size = np.multiply(prices_scaled, np.absolute(amounts_scaled))
        min_margin = utils.calculate_margin_requirement(v_scaled, k_scaled, size) * ids.LIQUIDITY_PRECISION
    %}
    // prank the approval and the add collateral calls
    %{
        ids.address = context.self_address
        start_prank(ids.ACCOUNT)
        ids.collateral = ids.MAX_LIQUIDATOR_PAY_OUT*2 - margin
        margin = ids.collateral + margin
    %}
    ERC20.approve(spender=address, amount=Uint256(collateral, 0));
    add_collateral(amount=collateral);

    %{
        assume(margin < min_margin and margin > ids.MAX_LIQUIDATOR_PAY_OUT)

        for (i, bit) in enumerate(sample_instruments):
            store(context.self_address, "storage_oracles", [prices[i]], key=[2**bit])
            store(context.self_address, "storage_positions", [fees[i], costs[i], amounts[i]], key=[ids.ACCOUNT, 2**bit])
            store(context.self_address, "storage_volatility", [volatility[i]], key=[2**bit])
            store(context.self_address, "storage_margin_parameters", [k[i], 0], key=[2**bit])
            store(context.self_address, "storage_longs", [longs[i]], key=[2**bit])
            store(context.self_address, "storage_shorts", [shorts[i]], key=[2**bit])
            store(context.self_address, "storage_liquidity", [liquidity[i]], key=[2**bit])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [instruments], key=[ids.ACCOUNT])
        expect_events({"name": "Liquidate", "data": [ids.ACCOUNT, instruments]})
    %}

    liquidate(owner=ACCOUNT);
    %{
        liquidity_change = (margin - ids.MAX_LIQUIDATOR_PAY_OUT)//length
        for (i, bit) in enumerate(sample_instruments):
            position = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**bit])
            new_liquidity = utils.signed_int(load(context.self_address, "storage_liquidity", "felt", key=[2**bit])[0])
            assert position == [0, 0, 0], f'position error, expected [0, 0, 0], got {position}'
            assert liquidity[i] + liquidity_change == new_liquidity, f'liquidity error, expected {liquidity[i] + liquidity_change}, got {new_liquidity}'
    %}
    return ();
}
