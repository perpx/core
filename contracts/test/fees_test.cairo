%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import compute_imbalance_fee, compute_fees

from starkware.cairo.common.math import unsigned_div_rem, abs_value

@storage_var
func storage_imbalance_fee_test() -> (imbalance_fee : felt):
end

@view
func get_imbalance_fee_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    ) -> (res : felt):
    let (res) = storage_imbalance_fee_test.read()
    return (res=res)
end

@external
func compute_imbalance_fee_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> (res):
    let (imbalance_fee) = compute_imbalance_fee(price, amount, long, short, liquidity)
    return (res=imbalance_fee)
end

@external
func compute_fees_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    price : felt, amount : felt, long : felt, short : felt, liquidity : felt
) -> (res : felt):
    let (fees) = compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )
    return (res=fees)
end
