// The max price from an asset oracle (in USDC including 6 decimals)
const MAX_PRICE = 10 ** 13;

// The range check bound allows verification that a number is between [0, 2**128)
const RANGE_CHECK_BOUND = 2 ** 128;

// The prime is the range bound for felt on cairo
const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;

// Project limit
const LIMIT = 2 ** 64;

// Project limit for user liquidity -> 2**64//100
const LIQUIDITY_LIMIT = 184467440737095516;

// The minimal liquidity in a pool to enable trading
const MIN_LIQUIDITY = 10 ** 6;

// The max value used for range checks
const MAX_BOUND = 2 ** 127;

// the max value used for a div of unsigned_div_rem(value, div)
const MAX_DIV = 2 ** 123;

// The wad precision value
const WAD_PRECISION = 10 ** 18;

// The precision needed for the share calculation
const SHARE_PRECISION = 10 ** 8;

// The precision for the liquidity
const LIQUIDITY_PRECISION = 10 ** 6;

// The precision for the volatility fees
const VOLATILITY_FEE_RATE_PRECISION = 10 ** 4;

// The maximum amount paid out to a liquidator
const MAX_LIQUIDATOR_PAY_OUT = 10 ** 8;

// The minimum amount paid out to a liquidator
const MIN_LIQUIDATOR_PAY_OUT = 10 ** 7;

// The maximum size of the queues
const MAX_QUEUE_SIZE = 10 ** 3;
