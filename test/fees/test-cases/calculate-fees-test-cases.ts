
const MAX_PRICE = 10**13
const MAX_AMOUNT = 2 ** 19
const MIN_LIQUIDITY = 1
const MAX_LIQUIDITY = 2**122

//scenarios:
// 1. price: max price or 1
// 2. amount: max_amount or 0
// 3. long: max_amount * max_price or 0
// 4. short: max_amount * max_price or 0
// 5. liquidity: max_liquidity or min_liquidity

function random_inside_limit(array: Array<bigint>): Array<bigint> {
    let a: bigint = BigInt(Math.floor(Number(array[0])+Math.random()*Number(array[1])+1))
    let b: bigint = BigInt(Math.floor(Number(array[1])-Math.random()*Number(array[1])+1))
    return [a,b]
}

function random_outside_limit(array: Array<bigint>): Array<bigint> {
    let a: bigint = BigInt(Math.floor(Number(array[0])-Math.random()*Number(array[1])+1))
    let b: bigint = BigInt(Math.floor(Number(array[1])+Math.random()*Number(array[1])+1))
    return [a,b]
}

function non_random_outside_limit(array: Array<bigint>): Array<bigint> {
    let a: bigint = array[0]-1n
    let b: bigint = array[1]+1n
    return [a,b]
}

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
                    CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
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

// const base_prices = [BigInt(Math.random()*MAX_PRICE), (BigInt(MAX_PRICE) - BigInt(1))]
// const base_amounts = [-BigInt(MAX_AMOUNT), BigInt(MAX_AMOUNT)]
// const base_liquidities = [BigInt(MIN_LIQUIDITY), (BigInt(MAX_LIQUIDITY) - BigInt(1))]
// const base_longs = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]
// const base_shorts = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]

const base_prices = random_inside_limit(limit_prices)
const base_amounts = random_inside_limit(limit_amounts)
const base_liquidities =random_inside_limit(limit_liquidities)
const base_longs =random_inside_limit(limit_longs)
const base_shorts =random_inside_limit(limit_shorts)


// console.log(base_prices)
// console.log(base_amounts)
// console.log(base_liquidities)
// console.log(base_longs)
// console.log(base_shorts)

export const CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED: CalculateFeesInterface[] = []

for (const price of base_prices) {
    for (const amount of base_amounts) {
        for (const liquidity of base_liquidities) { 
            for (const long of base_longs) { 
                for (const short of base_shorts) { 
                    CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
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

const fail_prices = non_random_outside_limit(limit_prices)
const fail_amounts = non_random_outside_limit(limit_amounts)
const fail_liquidities =non_random_outside_limit(limit_liquidities)
const fail_longs =non_random_outside_limit(limit_longs)
const fail_shorts =non_random_outside_limit(limit_shorts)

// console.log(fail_prices)
// console.log(fail_amounts)
// console.log(fail_liquidities)
// console.log(fail_longs)
// console.log(fail_shorts)

export const CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED: CalculateFeesInterface[] = []

for (const price of fail_prices) {
    for (const amount of fail_amounts) {
        for (const liquidity of fail_liquidities) { 
            for (const long of fail_longs) { 
                for (const short of fail_shorts) { 
                    CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED.push(
                    {
                        description: `price ${price}, amount ${amount}, long ${long}, short ${short}, liquidity ${liquidity}`,
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


interface CalculateFeesInterface {
    description: string,
    price: bigint,
    amount: bigint,
    long: bigint,
    short: bigint,
    liquidity: bigint,
    error?: string,
}

export const CALCULATE_FEES_TEST_CASES_BASE: CalculateFeesInterface[] = [
    {
        description: "price 100000, amount 2, long 40 000, short 30 000, liquidity 100000",
        price: BigInt(100000),
        amount: BigInt(2),
        long: BigInt(40000),
        short: BigInt(30000),
        liquidity: BigInt(100000),
    },
    {
        description: "price 100000, amount -2, long 40000, short 30000, liquidity 100000",
        price: BigInt(100000),
        amount: BigInt(2),
        long: BigInt(40000),
        short: BigInt(30000),
        liquidity: BigInt(100000),
    },
    {
        description: "price 1000, amount 0, long 0, short 0, liquidity 10000000",
        price: BigInt(1000),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(10000000),
    },
    {
        description: "price 1000, amount 100000, long 0, short 0, liquidity 10000000",
        price: BigInt(1000),
        amount: BigInt(100000),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(10000000),
    },
    {
        description: "price 1000, amount -100000, long 0, short 0, liquidity 10000000",
        price: BigInt(1000),
        amount: BigInt(100000),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(10000000),
    },
]

export const CALCULATE_FEES_TEST_CASES_LIMIT: CalculateFeesInterface[] = [


    // limit price
    {
        description: "price LIMIT_PRICE, amount 0, long 0, short 0, liquidity 10000000",
        price: BigInt(MAX_PRICE),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(10000000),
    },
    {
        description: "price MAX_PRICE, amount 0, long 0, short 0, liquidity 10000000",
        price: BigInt(MAX_PRICE),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(MAX_LIQUIDITY) - BigInt(1),
    },
    // take some longs
    {
        description: "price MAX_PRICE, amount 0, long 0, short 0, liquidity 10000000",
        price: BigInt(MAX_PRICE),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(MAX_LIQUIDITY) - BigInt(1),
    },
    // check if we should let people have bigger position than the liquidity, here fee becomes 200% 
    {
        description: "price MAX_PRICE, amount MAX_AMOUNT, long 0, short 0, liquidity MIN_LIQUIDITY",
        price: BigInt(MAX_PRICE),
        amount: BigInt(MAX_AMOUNT),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(MIN_LIQUIDITY),
    },
    // check if we should let people have bigger position than the liquidity, here fee becomes 200% 
    {
        description: "price MAX_PRICE, amount MAX_AMOUNT, long 0, short 0, liquidity MAX_LIQUIDITY",
        price: BigInt(MAX_PRICE),
        amount: BigInt(MAX_AMOUNT),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(MAX_LIQUIDITY)-BigInt(1),
    },
]

export const CALCULATE_FEES_TEST_CASES_FAIL: CalculateFeesInterface[] = [
    {
        description: "price 0, amount 0, long 0, short 0, liquidity 0",
        price: BigInt(0),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(0),
        error: "AssertionError: div=0x0 is out of the valid range.",
    },
    //{
        //description: "price 0, amount 0, long 0, short 0, liquidity 10000000",
        //price: BigInt(0),
        //amount: BigInt(0),
        //long: BigInt(0),
        //short: BigInt(0),
        //liquidity: BigInt(0),
        //error: "AssertionError: div=0x0 is out of the valid range."
    //},
]
