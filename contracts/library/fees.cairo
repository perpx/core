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
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

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
    // @param amount The amount of traded instrument (precision: 6)
    // @param long The notional size of longs (precision: 12)
    // @param short The notional size of shorts(precision: 12)
    // @param liquidity The liquidity for the instrument (precision: 6)
    // @return imbalance_fee The imbalance fee for the trade
    func compute_imbalance_fee{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        price: felt, amount: felt, long: felt, short: felt, liquidity: felt
    ) -> (imbalance_fee: felt) {
        // calculate nominator of formula
        const precision_correction = 10 ** 12;
        tempvar prod = price * amount * (2 * long + price * amount - 2 * short);
        let (value, _) = signed_div_rem(prod, precision_correction, MAX_BOUND);

        // calculate denominator of formula
        tempvar div = 2 * liquidity;

        // calculate result
        let (imbalance_fee, _) = signed_div_rem(value, div, MAX_BOUND);

        return (imbalance_fee=imbalance_fee);
    }

    // @notice Computes the fees for the LP
    // @param amount The amount of provided liquity (precision: 6)
    // @param long The notional size of longs (precision: 12)
    // @param short The notional size of shorts(precision: 12)
    // @param liquidity The liquidity for the instrument (precision: 6)
    func compute_lp_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt, long: felt, short: felt, liquidity: felt
    ) -> (lp_fees: felt) {
        alloc_locals;
        const precision_correction = 10 ** 6;
        tempvar imbalance = long - short;
        tempvar abs_imbalance = abs_value(imbalance);
        let (abs_imbalance, _) = unsigned_div_rem(abs_imbalance, precision_correction);
        tempvar imbalance64x61 = Math64x61.fromFelt(abs_imbalance);

        tempvar liquidity64x61 = Math64x61.fromFelt(liquidity);
        tempvar new_liquidity64x61 = Math64x61.fromFelt(amount + liquidity);
        local ratio64x61 = Math64x61.div(liquidity64x61, new_liquidity64x61);
        let log64x61 = Math64x61.ln(ratio64x61);

        tempvar fees64x61 = -Math64x61.mul(imbalance64x61, log64x61);

        tempvar lp_fees = Math64x61.toFelt(fees64x61);

        return (lp_fees=lp_fees);
    }
}
