%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem

from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND, LIQUIDITY_PRECISION
from contracts.perpx_v1_exchange import Parameter
from lib.cairo_math_64x61.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Constants
//

const OWNER = 12345;
const INSTRUMENT_COUNT = 10;
const MATH_PRECISION = 2 ** 64 + 2 ** 61;

//
// Interface
//

@contract_interface
namespace TestContract {
    func verify_length_test(length: felt, instruments: felt) {
    }
    func init_prev_prices_test(prev_prices_len: felt, prev_prices: felt*) {
    }
    func update_volatility_test(instrument_count: felt) {
    }
    func update_prices_test(prices_len: felt, prices: felt*, instruments: felt) {
    }
    func update_margin_parameters_test(
        parameters_len: felt, parameters: Parameter*, instruments: felt
    ) {
    }
}

//
// Setup
//

@external
func __setup__() {
    alloc_locals;
    %{
        max_examples(200);
        context.contract_address = deploy_contract("./contracts/test/perpx_v1_exchange_test.cairo", [ids.OWNER, 1234, ids.INSTRUMENT_COUNT]).contract_address
    %}
    return ();
}

@external
func test_verify_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    let (local arr) = alloc();
    local instruments;
    local address;
    local length;
    %{
        assume(ids.random !=0)
        from random import randint, sample, random
        length = ids.random % ids.INSTRUMENT_COUNT
        length = length if length > 0 else 1
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.LIMIT)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        sign = 1 if random() < 0.5 else -1
        ids.length = length + randint(1, length) * sign
        ids.instruments = instruments

        ids.address = context.contract_address
    %}

    %{
        stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) 
        expect_revert()
    %}
    TestContract.verify_length_test(
        contract_address=address, length=length, instruments=instruments
    );
    %{ stop_prank_callable() %}
    return ();
}

@external
func test_init_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    let (local arr: felt*) = alloc();
    local address;
    local length;
    %{
        from random import randint
        length = ids.random % (ids.INSTRUMENT_COUNT - 1) + 1
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.LIMIT)
        if length != ids.INSTRUMENT_COUNT:
            expect_revert()
        ids.address = context.contract_address
        ids.length = length
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=ids.address) %}
    TestContract.init_prev_prices_test(
        contract_address=address, prev_prices_len=length, prev_prices=arr
    );
    %{
        stop_prank_callable() 
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    TestContract.init_prev_prices_test(
        contract_address=address, prev_prices_len=random, prev_prices=arr
    );
    return ();
}

@external
func test_update_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local address;
    %{
        ids.address = context.contract_address
        from random import seed,randint, random
        seed(ids.random)
        for i in range(ids.INSTRUMENT_COUNT):
            store(context.contract_address, "storage_prev_oracles", [randint(0, ids.LIMIT)], key=[2**i])
            store(context.contract_address, "storage_oracles", [randint(0, ids.LIMIT)], key=[2**i])
            store(context.contract_address, "storage_volatility", [randint(0, ids.LIMIT)], key=[2**i])
            lmbd_int = randint(1, ids.LIMIT)
            lmbd_frac = int(random() * 2**61)
            store(context.contract_address, "storage_margin_parameters", [0, lmbd_int+lmbd_frac], key=[2**i])
        ids.address = context.contract_address
    %}
    %{
        # get prev prices
        prev_prices = []
        prices = []
        lambdas = []
        vols = []
        for i in range(ids.INSTRUMENT_COUNT):
            prev_prices.append(load(ids.address, "storage_prev_oracles", "felt", key=[2**i])[0])
            prices.append(load(ids.address, "storage_oracles", "felt", key=[2**i])[0])
            lambdas.append(load(ids.address, "storage_margin_parameters", "Parameter", key=[2**i])[1])
            vols.append(load(ids.address, "storage_volatility", "Parameter", key=[2**i])[0])
    %}
    TestContract.update_volatility_test(
        contract_address=address, instrument_count=INSTRUMENT_COUNT
    );
    %{
        import math
        for i in range(ids.INSTRUMENT_COUNT):
            volatility = load(ids.address, "storage_volatility", "felt", key=[2**i])[0]
            p = prices[i] 
            prev_p = prev_prices[i] 
            vol = math.pow(math.log10(p/prev_p), 2) * 2**61 + lambdas[i] * vols[i] / 2**61
            diff = vol - volatility
            assert abs(diff / 2**61) < 1e-6, f'volatility error, expected error to be less than 1e-6, got {diff / 2**61}'
    %}
    return ();
}

@external
func test_updates{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(random: felt) {
    alloc_locals;
    let (local arr_prices) = alloc();
    let (local arr_parameters: Parameter*) = alloc();
    local instruments;
    local address;
    local length;
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        for i in range(length):
            memory[ids.arr_prices + i] = randint(0, ids.LIMIT)
            memory[ids.arr_parameters._reference_value + 2*i] = randint(0, ids.MATH_PRECISION)
            memory[ids.arr_parameters._reference_value + 2*i + 1] = randint(0, ids.MATH_PRECISION)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        ids.length = length
        ids.instruments = instruments

        last_prices = []
        for i in range(ids.INSTRUMENT_COUNT):
            price = randint(0, ids.LIMIT)
            last_prices.append(price)
            store(context.contract_address, "storage_oracles", [price], key=[2**i])

        ids.address = context.contract_address
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) %}
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr_prices, instruments=instruments
    );
    TestContract.update_margin_parameters_test(
        contract_address=address,
        parameters_len=length,
        parameters=arr_parameters,
        instruments=instruments,
    );
    %{
        stop_prank_callable() 
        instruments = ids.instruments
        mult = 1
        prices = []
        parameters = []
        while instruments != 0:
            lsb = instruments & 1
            if lsb != 0:
                price = load(ids.address, "storage_oracles", "felt", key=[mult])[0]
                parameter = load(ids.address, "storage_margin_parameters", "Parameter", key=[mult])
                prices.append(price)
                parameters.append(parameter)
            mult *= 2
            instruments >>= 1
        for (i, (price, parameter)) in enumerate(zip(prices, parameters)):
            assert price == memory[ids.arr_prices + i], f'instrument price error got {price}, expected {memory[ids.arr_prices + i]}'
            assert parameter[0] == memory[ids.arr_parameters._reference_value + 2*i], f'instrument parameter error got {parameter[0]}, expected {memory[ids.arr_parameters._reference_value + 2*i]}'
            assert parameter[1] == memory[ids.arr_parameters._reference_value + 2*i +1], f'instrument parameter error got {parameter[1]}, expected {memory[ids.arr_parameters._reference_value + 2*i + 1]}'

        for i in range(ids.INSTRUMENT_COUNT):
            price = load(ids.address, "storage_prev_oracles", "felt", key=[2**i])[0]
            assert last_prices[i] == price, f'last price error, expected {last_prices[i]}, got {price}'
    %}
    return ();
}
