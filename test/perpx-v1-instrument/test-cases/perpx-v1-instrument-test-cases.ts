interface InstrumentTestCase {
    description: string
    amount: bigint
    error?: string
}

const MAX_PRICE = BigInt(10 ** 13)
const MAX_AMOUNT = BigInt(2 ** 128) - 1n

const INSTRUMENT_LONGS_LIMIT_CASES: InstrumentTestCase[][] = [
    [
        {
            description: 'long MAX_AMOUNT at 1',
            amount: MAX_AMOUNT,
        },
        {
            description: 'long -MAX_AMOUNT at 1',
            amount: -MAX_AMOUNT,
        },
    ],
]

const INSTRUMENT_LONGS_REVERT_CASES: InstrumentTestCase[] = [
    {
        description: 'long -MAX_AMOUNT at 1',
        amount: -MAX_AMOUNT,
    },
    {
        description: 'long -MAX_AMOUNT at 1',
        amount: MAX_AMOUNT + 1n,
    },
    {
        description: 'long -MAX_AMOUNT/MAX_PRICE at MAX_PRICE',
        amount: -MAX_AMOUNT / MAX_PRICE,
    },
]

const INSTRUMENT_SHORTS_LIMIT_CASES: InstrumentTestCase[][] = [
    [
        {
            description: 'short MAX_AMOUNT at 1',
            amount: MAX_AMOUNT,
        },
        {
            description: 'short -MAX_AMOUNT at 1',
            amount: -MAX_AMOUNT,
        },
    ],
]

const INSTRUMENT_SHORTS_REVERT_CASES: InstrumentTestCase[] = [
    {
        description: 'short -MAX_AMOUNT at 1',
        amount: -MAX_AMOUNT,
    },
    {
        description: 'short -MAX_AMOUNT/MAX_PRICE at MAX_PRICE',
        amount: MAX_AMOUNT + 1n,
    },
]

export {
    INSTRUMENT_LONGS_LIMIT_CASES,
    INSTRUMENT_SHORTS_LIMIT_CASES,
    INSTRUMENT_LONGS_REVERT_CASES,
    INSTRUMENT_SHORTS_REVERT_CASES,
}
