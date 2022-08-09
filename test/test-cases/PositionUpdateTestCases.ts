interface PositionUpdateTestCase {
    description: string
    price: bigint
    amount: bigint
    feeBps: bigint
    error?: string
}

const POSITION_UPDATE_BASE_TEST_CASES: PositionUpdateTestCase[] = [
    {
        description: 'price 0, amount 0, feeBps 0',
        price: BigInt(0),
        amount: BigInt(0),
        feeBps: BigInt(0),
    },
    {
        description: 'price 1500, amount 0, feeBps 0',
        price: BigInt(1_500),
        amount: BigInt(0),
        feeBps: BigInt(0),
    },
    {
        description: 'price 0, amount 10, feeBps 0',
        price: BigInt(0),
        amount: BigInt(10),
        feeBps: BigInt(0),
    },
    {
        description: 'price 0, amount 0, feeBps 100',
        price: BigInt(0),
        amount: BigInt(0),
        feeBps: BigInt(100),
    },
    {
        description: 'price 1500, amount 10, feeBps 0',
        price: BigInt(1_500),
        amount: BigInt(10),
        feeBps: BigInt(0),
    },
    {
        description: 'price 0, amount 10, feeBps 100',
        price: BigInt(0),
        amount: BigInt(10),
        feeBps: BigInt(100),
    },
    {
        description: 'price 1500, amount 0, feeBps 100',
        price: BigInt(1_500),
        amount: BigInt(0),
        feeBps: BigInt(100),
    },
    {
        description: 'price 1500, amount 10, feeBps 100',
        price: BigInt(1_500),
        amount: BigInt(10),
        feeBps: BigInt(100),
    },
    // negative values
    {
        description: 'price 0, amount -10, feeBps 0',
        price: BigInt(0),
        amount: BigInt(-10),
        feeBps: BigInt(0),
    },
    {
        description: 'price 1500, amount -10, feeBps 0',
        price: BigInt(1_500),
        amount: BigInt(-10),
        feeBps: BigInt(0),
    },
    {
        description: 'price 0, amount -10, feeBps 100',
        price: BigInt(0),
        amount: BigInt(-10),
        feeBps: BigInt(100),
    },
    {
        description: 'price 1500, amount -10, feeBps 100',
        price: BigInt(1_500),
        amount: BigInt(-10),
        feeBps: BigInt(100),
    },
]

const POSITION_UPDATE_REVERT_TEST_CASES: PositionUpdateTestCase[][] = [
    [
        {
            description:
                'price 2**64, amount 2**65, feeBps 0, fails on abs_value',
            price: BigInt(2 ** 64),
            amount: BigInt(2 ** 65),
            feeBps: BigInt(0),
            error: 'AssertionError: value=680564733841876926926749214863536422912 is out of the valid range.',
        },
    ],
    [
        {
            description:
                'price 2**65, amount 2**64, feeBps 0, fails on abs_value',
            price: BigInt(2 ** 65),
            amount: BigInt(2 ** 64),
            feeBps: BigInt(0),
            error: 'AssertionError: value=680564733841876926926749214863536422912 is out of the valid range.',
        },
    ],
    [
        {
            description:
                'price 1, amount 2**82, feeBps 0, fails on positive amount',
            price: BigInt(1),
            amount: BigInt(2 ** 82),
            feeBps: BigInt(0),
            error: 'Value 3618502788666131213697322783095070105623107215331596699973092056135872020480',
        },
    ],
    [
        {
            description:
                'price 1, -amount 2**82, feeBps 0, fails on negative amount',
            price: BigInt(1),
            amount: -BigInt(2 ** 82),
            feeBps: BigInt(0),
            error: 'Value 3618502788666131213697322783095070105623107215331596699973092056135872020480',
        },
    ],
    [
        {
            description: 'price 10**13, amount 1, feeBps 1, fails on price',
            price: BigInt(10 ** 13),
            amount: BigInt(1),
            feeBps: BigInt(1),
            error: 'Value 3618502788666131213697322783095070105623107215331596699973092056135872020480',
        },
    ],
    [
        {
            description:
                'price 1, amount 2**81, feeBps 1, runs twice and fails on positive size',
            price: BigInt(1),
            amount: BigInt(2 ** 81),
            feeBps: BigInt(1),
            error: '',
        },
        {
            description:
                'price 1, amount 2**81, feeBps 1, runs twice and fails on positive size',
            price: BigInt(1),
            amount: BigInt(2 ** 81),
            feeBps: BigInt(1),
            error: 'Value 3618502788666131213697322783095070105623107215331596699973092056135872020480',
        },
    ],
    [
        {
            description:
                'price 1, amount -2**81, feeBps 1, runs twice and fails on negative size',
            price: BigInt(1),
            amount: -BigInt(2 ** 81),
            feeBps: BigInt(1),
            error: '',
        },
        {
            description:
                'price 1, amount -2**81, feeBps 1, runs twice and fails on negative size',
            price: BigInt(1),
            amount: -BigInt(2 ** 81),
            feeBps: BigInt(1),
            error: 'Value 3618502788666131213697322783095070105623107215331596699973092056135872020480',
        },
    ],
]

const POSITION_UPDATE_LIMIT_TEST_CASES: PositionUpdateTestCase[][] = [
    [
        {
            description: 'price 1, amount 2**82 - 1, feeBps 10_000',
            price: BigInt(1),
            amount: BigInt(2 ** 82) - BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 1, amount -2**82 + 1, feeBps 10_000',
            price: BigInt(1),
            amount: -BigInt(2 ** 82) + BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 10**13 - 1, amount 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 1, amount 2**81, feeBps 10_000',
            price: BigInt(1),
            amount: BigInt(2 ** 81),
            feeBps: BigInt(10_000),
        },
        {
            description: 'price 1, amount 2**81 - 1, feeBps 10_000',
            price: BigInt(1),
            amount: BigInt(2 ** 81) - BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 1, amount -2**81, feeBps 10_000',
            price: BigInt(1),
            amount: -BigInt(2 ** 81),
            feeBps: BigInt(10_000),
        },
        {
            description: 'price 1, amount -2**81 + 1, feeBps 10_000',
            price: BigInt(1),
            amount: -BigInt(2 ** 81) + BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 10**13 - 1, amount 2**81 - 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: BigInt(2 ** 81) - BigInt(1),
            feeBps: BigInt(10_000),
        },
        {
            description: 'price 10**13 - 1, amount 2**81 - 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: BigInt(2 ** 81) - BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 10**13 - 1, amount -2**81 + 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: -BigInt(2 ** 81) + BigInt(1),
            feeBps: BigInt(10_000),
        },
        {
            description: 'price 10**13 - 1, amount -2**81 + 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: -BigInt(2 ** 81) + BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 10**13 - 1, amount 2**82 + 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: BigInt(2 ** 82) - BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
    [
        {
            description: 'price 10**13 - 1, amount -2**82 + 1, feeBps 10_000',
            price: BigInt(10 ** 13) - BigInt(1),
            amount: -BigInt(2 ** 82) + BigInt(1),
            feeBps: BigInt(10_000),
        },
    ],
]

export {
    PositionUpdateTestCase,
    POSITION_UPDATE_BASE_TEST_CASES,
    POSITION_UPDATE_REVERT_TEST_CASES,
    POSITION_UPDATE_LIMIT_TEST_CASES,
}
