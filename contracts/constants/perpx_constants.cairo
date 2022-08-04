# The max price from an asset oracle (in USDC including 6 decimals)
const MAX_PRICE = 10000000000000

# The range check bound allows verification that a number is between [0, 2**128)
const RANGE_CHECK_BOUND = 2 ** 128

# The prime is the range bound for felt on cairo
const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1

# The range for the size of a trade should be in [0, 2**206) with 2**206 * MAX_PRICE < PRIME
const MAX_SIZE = 2 ** 206
