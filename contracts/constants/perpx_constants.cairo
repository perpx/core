# The max price from an asset oracle (in USDC including 6 decimals)
const MAX_PRICE = 10 ** 13

# The range check bound allows verification that a number is between [0, 2**128)
const RANGE_CHECK_BOUND = 2 ** 128

# The prime is the range bound for felt on cairo
const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1

# The range for the amount of a trade should be in [-2**82, 2**82]
const MAX_AMOUNT = 2 ** 82

# The max value used for range checks
const MAX_BOUND = 2 ** 127
