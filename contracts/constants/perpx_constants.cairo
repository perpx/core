# The max price from an asset oracle (in USDC including 6 decimals)
const MAX_PRICE = 10 ** 13

# The range check bound allows verification that a number is between [0, 2**128)
const RANGE_CHECK_BOUND = 2 ** 128

# The prime is the range bound for felt on cairo
const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1

# The range for the amount of a trade should be in [-2**64, 2**64]
const MAX_AMOUNT = 2 ** 64

# The range for the amount of collateral should be in [-2**64, 2**64]
const MAX_COLLATERAL = 2 ** 64

# The max value used for range checks
const MAX_BOUND = 2 ** 127

# the max value used for a div of unsigned_div_rem(value, div)
const MAX_DIV = 2 ** 123

# The wad precision value
const WAD_PRECISION = 10 ** 18

# The maximum liquidity value [0, 10**18)
const MAX_LIQUIDITY = 2 ** 64

# The precision needed for the share calculation
const SHARE_PRECISION = 10 ** 8

# The precision for the liquidity
const LIQUIDITY_PRECISION = 10 ** 6
