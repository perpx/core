%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_LIQUIDITY
from contracts.test.helpers import setup_helpers

#
# Setup
#

@external
func __setup__():
    setup_helpers()
    return ()
end

#
# Tests
#

# # keep that one
@external
func test_basis_compute_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    rand : felt
) -> ():
    alloc_locals
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity

    local volatility_fee_rate

    %{
        assume(ids.rand != 0)
        ## different random numbers for each value
        ids.price, ids.amount, ids.long,  ids.short, ids.liquidity = context.get_random_values(ids.MAX_PRICE, ids.MAX_AMOUNT, ids.MAX_LIQUIDITY, ids.rand)
        #ids.price = 1000
        #print('random')
        #print(ids.rand)
        #ids.amount = 1000
        #ids.long = 20000
        #ids.short = 10000
        #ids.liquidity = 100000

        ids.volatility_fee_rate = ids.rand % (10000)

        assume(ids.liquidity != 0)
    %}

    # compute imbalance fees
    Fees.write_volatility_fee_rate(volatility_fee_rate)

    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        volatility_fee = (abs(imbalance_fees) * ids.volatility_fee_rate) // 10**4

        fees = imbalance_fees + volatility_fee

        assert ids.imbalance_fees == context.unsigned_int(imbalance_fees), f'imbalance fees {ids.imbalance_fees} different from {context.unsigned_int(imbalance_fees)}'
        assert ids.fees == context.unsigned_int(fees), f'fees {ids.fees} different from {context.unsigned_int(fees)}'
    %}

    return ()
end

@external
func test_limit_compute_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    rand : felt
) -> ():
    alloc_locals
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity
    local volatility_fee_rate

    %{
        assume(ids.rand != 0)
        ## different random numbers for each value
        ids.price = ids.rand % (ids.MAX_PRICE)
        ids.amount = ids.rand % (ids.MAX_AMOUNT)
        ids.long = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.short = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.liquidity = ids.rand % (ids.MAX_LIQUIDITY)
        ids.volatility_fee_rate = ids.rand % (10000)

        assume(ids.liquidity != 0)
    %}

    Fees.write_volatility_fee_rate(volatility_fee_rate)

    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    let (local fees) = Fees.compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        volatility_fee = (abs(imbalance_fees) * ids.volatility_fee_rate) // 10**4

        fees = imbalance_fees + volatility_fee

        assert ids.imbalance_fees == context.unsigned_int(imbalance_fees), f'imbalance fees {ids.imbalance_fees} different from {context.unsigned_int(imbalance_fees)}'
        assert ids.fees == context.unsigned_int(fees), f'fees {ids.fees} different from {context.unsigned_int(fees)}'
    %}

    return ()
end
