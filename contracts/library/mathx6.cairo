from starkware.cairo.common.math_cmp import is_le, is_not_zero
from starkware.cairo.common.math import (
    assert_le,
    assert_lt,
    signed_div_rem,
    unsigned_div_rem,
    assert_not_zero,
)

from contracts.constants.perpx_constants import LIQUIDITY_PRECISION

namespace Mathx6 {
    const FRACT_PART = LIQUIDITY_PRECISION;
    const BOUND = 2 ** 127;
    const ONE = 1 * FRACT_PART;

    // @notice Multiples two fixed point values
    // @param x The multiplier
    // @param y The multiplicand
    // @return The product
    func mul{range_check_ptr}(x: felt, y: felt) -> felt {
        tempvar product = x * y;
        let (res, _) = signed_div_rem(product, FRACT_PART, BOUND);
        return res;
    }
}
