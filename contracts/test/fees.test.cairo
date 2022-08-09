%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import fee_bps, compute_fee_bps

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
