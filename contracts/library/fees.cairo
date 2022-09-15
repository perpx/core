%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import (
    unsigned_div_rem,
    signed_div_rem,
    assert_not_zero,
    abs_value,
    assert_lt,
)
from contracts.constants.perpx_constants import MAX_BOUND, VOLATILITY_FEE_RATE_PRECISION

//
// Storage
//

@storage_var
func storage_volatility_fee_rate() -> (volatility_fee_rate: felt) {
}

namespace Fees {
    //
    // Functions
    //

    // @notice Computes the total fees by adding the volatlity_fees to the imbalance_fee
    // @param price The price of the instrument
    // @param amount The amount of traded instrument
    // @param long The notional size of longs
    // @param short The notional size of shorts
    // @param liquidity The liquidity for the instrument
    // @return fees The fees for the trade
    func compute_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        price: felt, amount: felt, long: felt, short: felt, liquidity: felt
    ) -> (fees: felt) {
        alloc_locals;
        let (local volatility_fee_rate) = storage_volatility_fee_rate.read();
        let (local imbalance_fee) = compute_imbalance_fee(
            price=price, amount=amount, long=long, short=short, liquidity=liquidity
        );
        let abs_imbalance_fee = abs_value(imbalance_fee);
        let volatility_fee = volatility_fee_rate * abs_imbalance_fee;
        let (abs_volatility_fee, _) = unsigned_div_rem(
            volatility_fee, VOLATILITY_FEE_RATE_PRECISION
        );
        let fees = imbalance_fee + abs_volatility_fee;
        return (fees=fees);
    }

    // @notice Computes the imbalance fee for the trade
    // @param price The price of the instrument
    // @param amount The amount of traded instrument
    // @param long The notional size of longs
    // @param short The notional size of shorts
    // @param liquidity The liquidity for the instrument
    // @return imbalance_fee The imbalance fee for the trade
    func compute_imbalance_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        price: felt, amount: felt, long: felt, short: felt, liquidity: felt
    ) -> (imbalance_fee: felt) {
        // calculate nominator of formula
        tempvar value = price * amount * (2 * long + price * amount - 2 * short);

        // calculate denominator of formula
        tempvar div = 2 * liquidity;

        // calculate result
        let (imbalance_fee, _) = signed_div_rem(value, div, MAX_BOUND);

        return (imbalance_fee=imbalance_fee);
    }
}
