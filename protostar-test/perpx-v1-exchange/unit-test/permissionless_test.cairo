%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.perpx_v1_exchange.permissionless import (
    trade,
    close,
    add_liquidity,
    remove_liquidity,
    add_collateral,
    remove_collateral,
    liquidate,
    escape_close,
)
from src.openzeppelin.token.erc20.library import ERC20
from contracts.constants.perpx_constants import (
    RANGE_CHECK_BOUND,
    LIMIT,
    LIQUIDITY_PRECISION,
    MIN_LIQUIDITY,
    VOLATILITY_FEE_RATE_PRECISION,
    MAX_LIQUIDATOR_PAY_OUT,
    MIN_LIQUIDATOR_PAY_OUT,
    MAX_QUEUE_SIZE,
)
from contracts.perpx_v1_exchange.structures import Operation

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
        store(ids.address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
        store(ids.address, "storage_queue_limit", [100])
        for i in range(ids.INSTRUMENT_COUNT):
            store(ids.address, "storage_liquidity", [ids.MIN_LIQUIDITY * 10], key=[2**i])
        context.self_address = ids.address 
        max_examples(200)
    %}

    return ();
}

// TEST TRADE

@external
func test_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(random: felt) {
    alloc_locals;
    let (local amounts: felt*) = alloc();
    let (local instruments: felt*) = alloc();
    let (local timestamps: felt*) = alloc();
    local length;
    %{
        from random import randint, seed, sample
        seed(ids.random)
        ids.length = ids.random % ids.INSTRUMENT_COUNT + 1
        instruments = [2**i for i in sample(range(0, ids.INSTRUMENT_COUNT), ids.length)]
        amounts = [randint(1, ids.LIMIT) for i in range(ids.length)]
        timestamps = [randint(1, ids.LIMIT) for i in range(ids.length)]
        for i in range(ids.length): 
            memory[ids.amounts + i] = amounts[i]
            memory[ids.instruments + i] = instruments[i]
            memory[ids.timestamps + i] = timestamps[i]
        start_prank(ids.ACCOUNT)
    %}
    loop_trade(
        amounts_len=length,
        amounts=amounts,
        instruments_len=length,
        instruments=instruments,
        ts_len=length,
        ts=timestamps,
    );
    %{
        count = load(context.self_address, "storage_operations_count", "felt")[0]
        assert count == ids.length, f'length error, expected {ids.length}, got {count}'
        for i in range(count):
            trade = load(context.self_address, "storage_operations_queue", "QueuedOperation", key=[i])
            assert trade[0] == ids.ACCOUNT, f'caller error, expected {ids.ACCOUNT}, got {trade[0]}'
            assert trade[1] == amounts[i], f'amounts error, expected {amounts[i]}, got {trade[1]}'
            assert trade[2] == instruments[i], f'amount error, expected {instruments[i]}, got {trade[2]}'
            assert trade[3] == timestamps[i], f'timestamp error, expected {timestamps[i]}, got {trade[3]}'
            assert trade[4] == ids.Operation.trade, f'operation error, expected {ids.Operation.trade}, got {trade[4]}'
    %}
    return ();
}

func loop_trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amounts_len: felt,
    amounts: felt*,
    instruments_len: felt,
    instruments: felt*,
    ts_len: felt,
    ts: felt*,
) {
    if (amounts_len == 0) {
        return ();
    }
    trade(amount=[amounts], instrument=[instruments], valid_until=[ts]);
    loop_trade(
        amounts_len=amounts_len - 1,
        amounts=amounts + 1,
        instruments_len=instruments_len - 1,
        instruments=instruments + 1,
        ts_len=ts_len - 1,
        ts=ts + 1,
    );
    return ();
}
// TEST CLOSE

@external
func test_close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(random: felt) {
    alloc_locals;
    let (local instruments: felt*) = alloc();
    let (local timestamps: felt*) = alloc();
    local length;
    %{
        from random import randint, seed, sample
        seed(ids.random)
        ids.length = ids.random % ids.INSTRUMENT_COUNT + 1
        instruments = [2**i for i in sample(range(0, ids.INSTRUMENT_COUNT), ids.length)]
        timestamps = [randint(1, ids.LIMIT) for i in range(ids.length)]
        for i in range(ids.length): 
            memory[ids.instruments + i] = instruments[i]
            memory[ids.timestamps + i] = timestamps[i]
        start_prank(ids.ACCOUNT)
    %}
    loop_close(instruments_len=length, instruments=instruments, ts_len=length, ts=timestamps);
    %{
        count = load(context.self_address, "storage_operations_count", "felt")[0]
        assert count == ids.length, f'length error, expected {ids.length}, got {count}'
        for i in range(count):
            close = load(context.self_address, "storage_operations_queue", "QueuedOperation", key=[i])
            assert close[0] == ids.ACCOUNT, f'caller error, expected {ids.ACCOUNT}, got {close[0]}'
            assert close[2] == instruments[i], f'amount error, expected {instruments[i]}, got {close[2]}'
            assert close[3] == timestamps[i], f'timestamp error, expected {timestamps[i]}, got {close[3]}'
            assert close[4] == ids.Operation.close, f'operation error, expected {ids.Operation.close}, got {close[4]}'
    %}
    return ();
}

func loop_close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instruments_len: felt, instruments: felt*, ts_len: felt, ts: felt*
) {
    if (instruments_len == 0) {
        return ();
    }
    close(instrument=[instruments], valid_until=[ts]);
    loop_close(
        instruments_len=instruments_len - 1,
        instruments=instruments + 1,
        ts_len=ts_len - 1,
        ts=ts + 1,
    );
    return ();
}

// TEST ESCAPE CLOSE

@external
func test_escape_close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local instrument;

    // create a fake positions for the user
    %{
        start_prank(ids.ACCOUNT)
        from random import randint, sample, seed
        import importlib  
        utils = importlib.import_module("protostar-test.perpx-v1-exchange.utils")
        seed(0)
        instrument = randint(0, ids.INSTRUMENT_COUNT - 1)
        ids.instrument = 2**instrument

        # generate random datas 
        price = randint(1, ids.LIMIT)
        cost = randint(-ids.LIMIT, ids.LIMIT)
        fee = randint(-ids.LIMIT, ids.LIMIT)
        collateral = randint(1, ids.LIMIT)
        amount = randint(-ids.LIMIT//price, ids.LIMIT//price)
        longs = randint(abs(amount), ids.LIMIT//price + 1)
        shorts = randint(abs(amount), ids.LIMIT//price + 1)
        liquidity = randint(1e6, ids.LIMIT)
        fee_rate = randint(0, ids.VOLATILITY_FEE_RATE_PRECISION)

        store(context.self_address, "storage_positions", [fee, cost, amount], key=[ids.ACCOUNT, 2**instrument])
        store(context.self_address, "storage_oracles", [price], key=[2**instrument])
        store(context.self_address, "storage_longs", [longs], key=[2**instrument])
        store(context.self_address, "storage_shorts", [shorts], key=[2**instrument])
        store(context.self_address, "storage_liquidity", [liquidity], key=[2**instrument])
        store(context.self_address, "storage_collateral", [collateral], key=[ids.ACCOUNT])
        store(context.self_address, "storage_volatility_fee_rate", [fee_rate])
        store(context.self_address, "storage_user_instruments", [2**instrument], key=[ids.ACCOUNT])

        store(context.self_address, "storage_is_escaping", [1])
    %}

    // escape close
    escape_close(instrument=instrument);
    %{
        fees_change = utils.calculate_fees(price, -amount, longs, shorts, liquidity, fee_rate, ids.VOLATILITY_FEE_RATE_PRECISION)
        new_cost = cost +  -amount * price
        delta = -new_cost - fees_change - fee

        c = utils.signed_int(load(context.self_address, "storage_collateral", "felt", key=[ids.ACCOUNT])[0])
        position = load(context.self_address, "storage_positions", "Info", key=[ids.ACCOUNT, 2**instrument])
        new_instruments = load(context.self_address, "storage_user_instruments", "felt", key=[ids.ACCOUNT])[0]
        assert position == [0, 0, 0], f'position error, expected [0, 0, 0], got {position}'
        assert c == collateral + delta, f'collateral error, expected {collateral + delta}, got {collateral}'
        assert new_instruments == 0, f'instruments error, expected 0, got {new_instruments}'

        if amount > 0:
            new_longs = load(context.self_address, "storage_longs", "felt", key=[2**instrument])[0]
            assert new_longs == longs - amount, f'longs error, expected {longs - amount}, got {new_longs}'
        else:
            new_shorts = load(context.self_address, "storage_shorts", "felt", key=[2**instrument])[0]
            assert new_shorts == shorts - abs(amount), f'shorts error, expected {shorts - abs(amount)}, got {new_shorts}'
    %}
    return ();
}

// TEST LIQUIDATE

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
            liq = liquidity[i] + liquidity_change if liquidity[i] + liquidity_change > 0 else 0
            assert liq == new_liquidity, f'liquidity error, expected {liq}, got {new_liquidity}'
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
    random: felt
) {
    alloc_locals;
    let (local amounts: felt*) = alloc();
    let (local timestamps: felt*) = alloc();
    local length;
    %{
        from random import randint, seed
        seed(ids.random)
        ids.length = ids.random % 10 + 1
        amounts = [randint(1, ids.LIMIT) for i in range(ids.length)]
        timestamps = [randint(1, ids.LIMIT) for i in range(ids.length)]
        for i in range(ids.length): 
            memory[ids.amounts + i] = amounts[i]
            memory[ids.timestamps + i] = timestamps[i]
        start_prank(ids.ACCOUNT)
    %}
    loop_remove(amounts_len=length, amounts=amounts, ts_len=length, ts=timestamps);
    %{
        count = load(context.self_address, "storage_operations_count", "felt")[0]
        assert count == ids.length, f'length error, expected {ids.length}, got {count}'
        for i in range(count):
            collateral = load(context.self_address, "storage_operations_queue", "QueuedOperation", key=[i])
            assert collateral[0] == ids.ACCOUNT, f'caller error, expected {ids.ACCOUNT}, got {collateral[0]}'
            assert collateral[1] == amounts[i], f'amount error, expected {amounts[i]}, got {collateral[1]}'
            assert collateral[3] == timestamps[i], f'timestamp error, expected {timestamps[i]}, got {collateral[3]}'
    %}
    return ();
}

func loop_remove{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amounts_len: felt, amounts: felt*, ts_len: felt, ts: felt*
) {
    if (amounts_len == 0) {
        return ();
    }
    remove_collateral(amount=[amounts], valid_until=[ts]);
    loop_remove(amounts_len=amounts_len - 1, amounts=amounts + 1, ts_len=ts_len - 1, ts=ts + 1);
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
