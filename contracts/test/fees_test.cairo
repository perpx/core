%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees

from starkware.cairo.common.math import unsigned_div_rem, abs_value

@external
func compute_imbalance_fee_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, amount: felt, long: felt, short: felt, liquidity: felt
) -> (res: felt) {
    let (imbalance_fee) = Fees.compute_imbalance_fee(price, amount, long, short, liquidity);
    return (res=imbalance_fee);
}

@external
func compute_fees_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, amount: felt, long: felt, short: felt, liquidity: felt
) -> (res: felt) {
    let (fees) = Fees.compute_fees(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    );
    return (res=fees);
}
