%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, signed_div_rem, assert_not_zero, abs_value
from contracts.constants.perpx_constants import MAX_BOUND, VOLATILITY_FEE_RATE_PRECISION

@storage_var
func storage_volatility_fee_rate() -> (volatility_fee_rate : felt):
end

# @notice Computes the total fees by adding the volatlity_fees to the imbalance_fee
# @param price The price of the instrument
# @param amount Number of assets to buy
# @param long Size of the longs for that instrument
# @param short Size of the shorts for that instrument
# @param liquidity Size of the liquidity for that instrument
func compute_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> (fees : felt):
    alloc_locals
    let (local volatility_fee_rate) = storage_volatility_fee_rate.read()
    let (local imbalance_fee) = compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )
    let volatility_fee = volatility_fee_rate * imbalance_fee
    let (abs_volatility_fee) = abs_value(volatility_fee)
    let (abs_volatility_fee, _) = unsigned_div_rem(
        abs_volatility_fee, VOLATILITY_FEE_RATE_PRECISION
    )
    let fees = imbalance_fee + abs_volatility_fee
    return (fees=fees)
end

# @notice Computes the imbalance_fee based on the instrument state and user size
# @param price The price of the instrument
# @param amount Number of assets to buy
# @param long Size of the longs for that instrument
# @param short Size of the shorts for that instrument
# @param liquidity Size of the liquidity for that instrument
func compute_imbalance_fee{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> (imbalance_fee : felt):
    alloc_locals

    # #  checks that price is not equal to 0
    assert_not_zero(price)

    # # calculate nominator of formula
    tempvar value = price * amount * (2 * long + price * amount - 2 * short)

    # # # calculate denominator of formula
    tempvar div = 2 * liquidity

    # # # calculate result
    # let (local imbalance_fee, _) = unsigned_div_rem(value, div)
    let (local imbalance_fee, _) = signed_div_rem(value, div, MAX_BOUND)

    return (imbalance_fee)
end

# func range_check_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
# price : felt,
# amount : felt,
# long : felt,
# short : felt,
# liquidity : felt,
# value : felt,
# div : felt,
# ) -> ():
# # # cannot be negative
# [range_check_ptr] = price
# assert [range_check_ptr + 1] = MAX_PRICE - price - 1

# assert [range_check_ptr + 2] = amount + MAX_AMOUNT
# assert [range_check_ptr + 3] = MAX_AMOUNT - amount - 1

# # # can be negative
# # # not too small
# assert [range_check_ptr + 4] = value + MAX_BOUND
# # # not too big
# assert [range_check_ptr + 5] = MAX_BOUND - value - 1

# [range_check_ptr + 6] = div
# assert [range_check_ptr + 7] = MAX_DIV - div - 1

# let range_check_ptr = range_check_ptr + 8

# return ()
# end

@external
func write_volatility_fee_rate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    fee : felt
) -> ():
    storage_volatility_fee_rate.write(fee)
    return ()
end
