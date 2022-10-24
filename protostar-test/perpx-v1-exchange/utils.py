from starkware.python.math_utils import isqrt
import numpy as np
import math

FRACT_PART = 2**61
LIQUIDITY_PRECISION = 10**6
PRIME = 2**251 + 17 * 2**192 + 1
BOUND = 2**125


def fromFelt(x):
    x = x * FRACT_PART
    assert64x61(x)
    return x

# Multiples two fixed point values and checks for overflow before returning


def mul(x, y):
    product = x * y
    res = product // FRACT_PART
    assert64x61(res)
    return res

# asserts x is 64x61


def assert64x61(x):
    assert x < BOUND or x > PRIME - BOUND


def sqrt(x):
    return isqrt(x) * FRACT_PART // isqrt(FRACT_PART)

# x is a 64x61 fixed point value


def interp_exp2(x):
    int_part = math.exp(x // FRACT_PART) * FRACT_PART
    x = x % FRACT_PART
    # 1.069e-7 maximum error
    a1 = 2305842762765193127
    a2 = 1598306039479152907
    a3 = 553724477747739017
    a4 = 128818789015678071
    a5 = 20620759886412153
    a6 = 4372943086487302

    r6 = mul(a6, x)
    r5 = mul(r6 + a5, x)
    r4 = mul(r5 + a4, x)
    r3 = mul(r4 + a3, x)
    r2 = mul(r3 + a2, x)
    fract_part = r2 + a1
    return mul(int_part, fract_part)


def interp_exp(x):
    mod = 3326628274461080623
    bin_exp = mul(x, mod)
    return interp_exp2(bin_exp)


def from_64x61_to_liquidity_precision(x):
    return x // (FRACT_PART // LIQUIDITY_PRECISION)


def calculate_margin_requirement(volatility, k, size):
    l = np.maximum(np.exp(np.multiply(np.sqrt(volatility), k)) - 1, 1/100)
    return np.sum(np.multiply(size, l))


def calculate_exit_fees(prices, amounts, longs, shorts, liquidity, fee_rate, fee_precision):
    imbalance_exit_fees = [calculate_imbalance_fees(
        prices[i], -amounts[i], longs[i], shorts[i], liquidity[i]) for i in range(len(prices))]
    volatility_exit_fees = sum(
        [abs(x) * fee_rate // fee_precision for x in imbalance_exit_fees])
    return sum(imbalance_exit_fees) + volatility_exit_fees


def calculate_imbalance_fees(price, amount, longs, shorts, liquidity):
    return price*amount*(2*longs*price + price*amount - 2*shorts*price) // 10**12 // (2*liquidity)


def calculate_fees(price, amount, longs, shorts, liquidity, fee_rate, fee_precision):
    fees_change = calculate_imbalance_fees(
        price, amount, longs, shorts, liquidity)
    return fees_change + abs(fees_change) * fee_rate // fee_precision


def calculate_longs_shorts_change(amount, size):
    sign_size = math.copysign(1, size)
    sign_amount = math.copysign(1, amount)
    if sign_size == sign_amount:
        if amount > 0:
            return amount, 0
        else:
            return 0, abs(amount)
    else:
        if amount > 0:
            if amount < abs(size):
                return 0, -amount
            else:
                return amount + size, size
        else:
            if abs(amount) < size:
                return amount, 0
            else:
                return -size, abs(size + amount)


def calculate_collateral_change(price, size, cost, fees):
    return -(price*(-size)//10**6 + cost) - fees


def signed_int(value):
    return value if value <= PRIME/2 else -(PRIME - value)
