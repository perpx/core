%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees_test import get_imbalance_fee_bps, compute_imbalance_fee_bps_test
from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_LIQUIDITY

#
# Constants
#

@contract_interface
namespace TestContract:
    func get_imbalance_fee_bps() -> (res : felt):
    end
    func compute_imbalance_fee_bps_test(
        price : felt, amount : felt, long : felt, short : felt, liquidity : felt
    ) -> ():
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
        context.contract_address = deploy_contract("./contracts/test/fee_test.cairo").contract_address
        ids.address = context.contract_address
    %}

    return ()
end

#
# Tests
#

@external
func test_compute_fee_bps{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    rand : felt
) -> ():
    alloc_locals
    local address
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity

    %{
        ids.address = context.contract_address
        assume(ids.rand != 0)
        ids.price = ids.rand % (MAX_PRICE)
        ids.amount = ids.rand % (MAX_AMOUNT)
        ids.long = ids.rand % (MAX_PRICE*MAX_AMOUNT)
        ids.short = ids.rand % (MAX_PRICE*MAX_AMOUNT)
        ids.liquidity = ids.rand % (MAX_LIQUIDITY)
    %}

    # compute fee bps
    TestContract.compute_imbalance_fee_bps_test(
        contract_address=contract_address,
        price=price,
        amount=amount,
        long=long,
        short=short,
        liquidity=liquidity,
    )

    # get computed fee bps
    let (local fee_bps) = TestContract.get_imbalance_fee_bps(contract_address=contract_address)

    %{ assert (ids.fee_bps) == 1000000 %}

    return ()
end
