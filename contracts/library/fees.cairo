%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_BOUND

@storage_var
func storage_fee_bps() -> (feeBps : felt):
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
    # # calculate nominator of formula
    tempvar nominator = price * amount * (2 * long + (price * amount) - 2 * short)
    # # assert that the bound is respected
    [range_check_ptr] = nominator
    assert [range_check_ptr + 1] = MAX_BOUND - nominator

    # # calculate denominator of formula
    tempvar denominator = 2 * liquidity
    [range_check_ptr + 2] = denominator
    assert [range_check_ptr + 3] = MAX_BOUND - denominator

    let range_check_ptr = range_check_ptr + 4

    # # calculate result
    let (local fee_bps, _) = unsigned_div_rem(nominator, denominator)

    storage_fee_bps.write(fee_bps)

    return ()
end
