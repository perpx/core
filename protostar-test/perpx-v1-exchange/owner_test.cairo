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

#
# Constants
#

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1
const OWNER = 12345
const INSTRUMENT_COUNT = 10

#
# Interface
#

@contract_interface
namespace TestContract:
    func view_price_test(instrument : felt) -> ():
    end
    func update_prices_test(prices_len : felt, prices : felt*, instruments : felt):
    end
end

#
# Setup
#

@external
func __setup__():
    alloc_locals
    local address
    %{ context.contract_address = deploy_contract("./contracts/test/perpx_v1_exchange_test.cairo", [ids.OWNER, 1234, ids.INSTRUMENT_COUNT]).contract_address %}

    return ()
end

@external
func test_update_prices_revert{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr, instruments=instruments
    )
    %{ stop_prank_callable() %}
    return ()
end

@external
func test_update_prices_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    let (local arr) = alloc()
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.MAX_PRICE)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        ids.length = length
        ids.instruments = instruments

        ids.address = context.contract_address
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) %}
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr, instruments=instruments
    )
    %{
        stop_prank_callable() 
        instruments = ids.instruments
        mult = 1
        prices = []
        while instruments != 0:
            lsb = instruments & 1
            if lsb != 0:
                price = load(ids.address, "storage_oracles", "felt", key=[mult])[0]
                prices.append(price)
            mult *= 2
            instruments >>= 1
        for (i, p) in enumerate(prices):
            assert p == memory[ids.arr + i], f'instrument price error got {p}, expected {memory[ids.arr + i]}'
    %}
    return ()
end
