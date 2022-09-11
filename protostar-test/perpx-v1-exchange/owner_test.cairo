%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from contracts.constants.perpx_constants import (
    MAX_LIQUIDITY,
    RANGE_CHECK_BOUND,
    MAX_PRICE,
    MAX_AMOUNT,
)
from contracts.perpx_v1_exchange import Parameter

#
# Constants
#

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1
const OWNER = 12345
const INSTRUMENT_COUNT = 10
const MATH_PRECISION = 2 ** 64 + 2 ** 61

#
# Interface
#

@contract_interface
namespace TestContract:
    func view_price_test(instrument : felt) -> ():
    end
    func update_prices_test(prices_len : felt, prices : felt*, instruments : felt):
    end
    func update_margin_parameters_test(
        parameters_len : felt, parameters : Parameter*, instruments : felt
    ):
    end
    func verify_length_test(length : felt, instruments : felt):
    end
end

#
# Setup
#

@external
func __setup__():
    alloc_locals
    local address
    %{
        context.contract_address = deploy_contract("./contracts/test/perpx_v1_exchange_test.cairo", [ids.OWNER, 1234, ids.INSTRUMENT_COUNT]).contract_address 
        store(context.contract_address, "storage_msb_instrument", [2**(ids.INSTRUMENT_COUNT - 1)])
    %}

    return ()
end

@external
func test_verify_length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    let (local arr) = alloc()
    local instruments
    local address
    local length
    %{
        assume(ids.random !=0)
        from random import randint, sample, random
        length = ids.random % ids.INSTRUMENT_COUNT
        length = length if length > 0 else 1
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.MAX_PRICE)
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
    )
    %{ stop_prank_callable() %}
    return ()
end

@external
func test_updates{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(random : felt):
    alloc_locals
    let (local arr_prices) = alloc()
    let (local arr_parameters : Parameter*) = alloc()
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        for i in range(length):
            memory[ids.arr_prices + i] = randint(0, ids.MAX_PRICE)
            memory[ids.arr_parameters._reference_value + 2*i] = randint(0, ids.MATH_PRECISION)
            memory[ids.arr_parameters._reference_value + 2*i + 1] = randint(0, ids.MATH_PRECISION)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        ids.length = length
        ids.instruments = instruments

        last_prices = []
        for i in range(ids.INSTRUMENT_COUNT):
            price = randint(0, ids.MAX_PRICE)
            last_prices.append(price)
            store(context.contract_address, "storage_oracles", [price], key=[2**i])

        ids.address = context.contract_address
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) %}
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr_prices, instruments=instruments
    )
    TestContract.update_margin_parameters_test(
        contract_address=address,
        parameters_len=length,
        parameters=arr_parameters,
        instruments=instruments,
    )
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
    return ()
end
