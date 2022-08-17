
const MAX_PRICE = 10**13
const MAX_AMOUNT = 2 ** 19
const MIN_LIQUIDITY = 1
const MAX_LIQUIDITY = 2**122

//scenarios:
// 0. volatility_fee: 
// 1. price: max price or 1
// 2. amount: max_amount or 0
// 3. long: max_amount * max_price or 0
// 4. short: max_amount * max_price or 0
// 5. liquidity: max_liquidity or min_liquidity

interface CalculateFeesInterface {
    description: string,
    volatility_fee: bigint,
    price: bigint,
    amount: bigint,
    long: bigint,
    short: bigint,
    liquidity: bigint,
    error?: string,
}

function random_inside_limit(array: Array<bigint>): Array<bigint> {
    let a: bigint = BigInt(Math.floor(Number(array[0])+Math.random()*Number(array[1])+1))
    let b: bigint = BigInt(Math.floor(Number(array[1])-Math.random()*Number(array[1])+1))
    return [a,b]
}

function non_random_outside_limit(array: Array<bigint>): Array<bigint> {
    let a: bigint = array[0]-1n
    let b: bigint = array[1]+1n
    return [a,b]
}

const limit_volatility_fees = [BigInt(100_000)]
const limit_prices = [BigInt(1), (BigInt(MAX_PRICE) - BigInt(1))]
const limit_amounts = [-BigInt(MAX_AMOUNT), BigInt(MAX_AMOUNT)]
const limit_liquidities = [BigInt(MIN_LIQUIDITY), (BigInt(MAX_LIQUIDITY) - BigInt(1))]
const limit_longs = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]
const limit_shorts = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]

export const CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED: CalculateFeesInterface[] = []

for (const price of limit_prices) {
    for (const amount of limit_amounts) {
        for (const liquidity of limit_liquidities) { 
            for (const long of limit_longs) { 
                for (const short of limit_shorts) { 
                    for(const volatility_fee of limit_volatility_fees)
                    CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
                        volatility_fee: volatility_fee,
                        price: price,
                        amount: amount,
                        long: long,
                        short: short,
                        liquidity: liquidity,
                    }
                )}
            }
        }
    }
}

const base_volatility_fees = [BigInt(100_000)]
const base_prices = random_inside_limit(limit_prices)
const base_amounts = random_inside_limit(limit_amounts)
const base_liquidities =random_inside_limit(limit_liquidities)
const base_longs =random_inside_limit(limit_longs)
const base_shorts =random_inside_limit(limit_shorts)

export const CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED: CalculateFeesInterface[] = []

for (const price of base_prices) {
    for (const amount of base_amounts) {
        for (const liquidity of base_liquidities) { 
            for (const long of base_longs) { 
                for (const short of base_shorts) { 
                    for (const volatility_fee of base_volatility_fees) {
                    CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
                        volatility_fee: volatility_fee,
                        price: price,
                        amount: amount,
                        long: long,
                        short: short,
                        liquidity: liquidity,
                    }
                )}
                }
            }
        }
    }
}

// FAIL SCENARIOS
const fail_volatility_fees = [BigInt(100_000)]
const fail_prices = non_random_outside_limit(limit_prices)
const fail_amounts = non_random_outside_limit(limit_amounts)
const fail_liquidities =non_random_outside_limit(limit_liquidities)
const fail_longs =non_random_outside_limit(limit_longs)
const fail_shorts =non_random_outside_limit(limit_shorts)

export const CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED: CalculateFeesInterface[] = []

for (const price of fail_prices) {
    for (const amount of fail_amounts) {
        for (const liquidity of fail_liquidities) { 
            for (const long of fail_longs) { 
                for (const short of fail_shorts) { 
                    for (const volatility_fee of fail_volatility_fees) {
                    CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
                        volatility_fee: volatility_fee,
                        price: price,
                        amount: amount,
                        long: long,
                        short: short,
                        liquidity: liquidity,
                        error: "in range check builtin 1, is out of range"
                    }
                )}
            }
        }
    }
}
}