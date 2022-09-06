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
const ACCOUNT = 123
const INSTRUMENT_COUNT = 10

#
# Interface
#

@contract_interface
namespace TestContract:
    func calculate_pnl_test(owner : felt, instruments : felt) -> (pnl : felt):
    end
    func calculate_fees_test(owner : felt, instruments : felt) -> (fees : felt):
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
func test_calculate_pnl{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        instruments = 0
        pnl = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            inst = 1 << bit
            instruments |= inst

            price = randint(0, ids.MAX_PRICE)
            amount = randint(0, ids.MAX_AMOUNT)
            cost = randint(0, ids.MAX_AMOUNT)
            pnl += price * amount - cost

            store(context.contract_address, "storage_oracles", [price], key=[inst])
            store(context.contract_address, "storage_positions", [0, cost, amount], key=[ids.ACCOUNT, inst])

        ids.length = length
        ids.instruments = instruments

        ids.address = context.contract_address
    %}
    let (local pnl) = TestContract.calculate_pnl_test(
        contract_address=address, owner=ACCOUNT, instruments=instruments
    )
    %{ assert pnl == ids.pnl, f'pnl error, expected {pnl}, got {ids.pnl}' %}
    return ()
end

@external
func test_calculate_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        instruments = 0
        fees = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            inst = 1 << bit
            instruments |= inst

            fee = randint(0, ids.MAX_AMOUNT)
            fees += fee

            store(context.contract_address, "storage_positions", [fee, 0, 0], key=[ids.ACCOUNT, inst])

        ids.length = length
        ids.instruments = instruments

        ids.address = context.contract_address
    %}
    let (local fees) = TestContract.calculate_fees_test(
        contract_address=address, owner=ACCOUNT, instruments=instruments
    )
    %{ assert fees == ids.fees, f'fees error, expected {fees}, got {ids.fees}' %}
    return ()
end
