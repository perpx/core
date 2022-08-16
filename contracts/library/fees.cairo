%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, signed_div_rem, assert_not_zero
from contracts.constants.perpx_constants import (
    MAX_PRICE,
    MAX_AMOUNT,
    MAX_BOUND,
    MAX_DIV,
    RANGE_CHECK_BOUND,
)

@storage_var
func storage_fee_bps() -> (feeBps : felt):
end

@storage_var
func storage_rest() -> (rest : felt):
end

func rest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = storage_rest.read()
    return (res=res)
end

func fee_bps{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = storage_fee_bps.read()
    return (res=res)
end

# @notice Computes the feeBps based on the instrument state and user size
# @param price The price of the instrument
# @param amount Number of assets to buy
# @param long Size of the longs for that instrument
# @param short Size of the shorts for that instrument
# @param liquidity Size of the liquidity for that instrument
func compute_fee_bps{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> ():
    alloc_locals

    # #  checks that price is not equal to 0
    assert_not_zero(price)

    # # calculate nominator of formula
    tempvar value = price * amount * (2 * long + price * amount - 2 * short)

    # # # calculate denominator of formula
    tempvar div = 2 * liquidity

    # # # range limits for all values
    range_check_fees(price, amount, long, short, liquidity, value, div)

    # # # calculate result
    # let (local fee_bps, _) = unsigned_div_rem(value, div)
    let (local fee_bps, local rest) = signed_div_rem(value, div, MAX_BOUND)

    storage_fee_bps.write(fee_bps)
    storage_rest.write(rest)

    return ()
end

func range_check_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt,
    amount : felt,
    long : felt,
    short : felt,
    liquidity : felt,
    value : felt,
    div : felt,
) -> ():
    # # cannot be negative
    [range_check_ptr] = price
    assert [range_check_ptr + 1] = MAX_PRICE - price - 1

    assert [range_check_ptr + 2] = amount + MAX_AMOUNT
    assert [range_check_ptr + 3] = MAX_AMOUNT - amount - 1

    # # can be negative
    # # not too small
    assert [range_check_ptr + 4] = value + MAX_BOUND
    # # not too big
    assert [range_check_ptr + 5] = MAX_BOUND - value - 1

    [range_check_ptr + 6] = div
    assert [range_check_ptr + 7] = MAX_DIV - div - 1

    let range_check_ptr = range_check_ptr + 8

    return ()
end
