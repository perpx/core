%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import fee_bps, compute_fee_bps, rest

from starkware.cairo.common.math import unsigned_div_rem, abs_value

@view
func get_rest{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (res) = rest()
    return (res=res)
end

@view
func get_fee_bps{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let (res) = fee_bps()
    return (res=res)
end

@external
func compute_fee_bps_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> ():
    compute_fee_bps(price, amount, long, short, liquidity)
    return ()
end

# @external
# func compute_fee_bps_test1{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
#     ):
#     let price = 9999999999999
#     let amount = -524288
#     let long = 5242869999999475713
#     let short = 0
#     let liquidity = 5316911983139663491615228241121378303
#     compute_fee_bps(price, amount, long, short, liquidity)
#     return ()
# end

# @external
# func compute_fee_bps_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     price : felt, amount : felt, long : felt, short : felt, liquidity : felt
# ) -> ():
#     # # calculate nominator of formula
#     tempvar value = price * amount * (2 * long + (price * amount) - 2 * short)
#     return (value)
# end
