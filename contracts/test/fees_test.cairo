%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import imbalance_fee_bps, compute_imbalance_fee_bps

from starkware.cairo.common.math import unsigned_div_rem, abs_value

@view
func get_imbalance_fee_bps{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    res : felt
):
    let (res) = imbalance_fee_bps()
    return (res=res)
end

@external
func compute_imbalance_fee_bps_test{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(price : felt, amount : felt, long : felt, short : felt, liquidity : felt) -> ():
    compute_imbalance_fee_bps(price, amount, long, short, liquidity)
    return ()
end
