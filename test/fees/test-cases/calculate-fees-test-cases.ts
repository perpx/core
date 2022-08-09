
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
    {
        description: "price 1000, amount 0, long 0, short 0, liquidity 10000000",
        price: BigInt(1000),
        amount: BigInt(0),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(10000000),
    },
    // check if we should let people have bigger position than the liquidity, here fee becomes 200% 
    {
        description: "price 100000, amount 2, long 0, short 0, liquidity 100000",
        price: BigInt(100000),
        amount: BigInt(2),
        long: BigInt(0),
        short: BigInt(0),
        liquidity: BigInt(100000),
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
