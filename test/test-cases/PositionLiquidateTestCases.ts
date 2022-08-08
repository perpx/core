import {
    PositionUpdateTestCase,
    POSITION_UPDATE_BASE_TEST_CASES,
    POSITION_UPDATE_LIMIT_TEST_CASES,
} from './PositionUpdateTestCases'

interface PositionLiquidateTestCase {
    description: string
    positionUpdate: PositionUpdateTestCase[]
    price: bigint
    feeBps: bigint
    error?: string
}

const POSITION_LIQUIDATE_BASE_TEST_CASES: PositionLiquidateTestCase[] = [
    // positive values
    {
        description:
            'price 0, feeBps 0, positionUpdate price 1500, amount 10, feeBps 100',
        price: BigInt(0),
        feeBps: BigInt(0),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    {
        description:
            'price 1500, feeBps 0, positionUpdate price 1500, amount 10, feeBps 100',
        price: BigInt(1500),
        feeBps: BigInt(0),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    {
        description:
            'price 0, feeBps 10, positionUpdate price 1500, amount 10, feeBps 100',
        price: BigInt(0),
        feeBps: BigInt(10),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    {
        description:
            'price 1500, feeBps 10, positionUpdate price 1500, amount 10, feeBps 100',
        price: BigInt(1500),
        feeBps: BigInt(10),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    // negative values
    {
        description:
            'price 0, feeBps 0, positionUpdate price 1500, amount -10, feeBps 100',
        price: BigInt(0),
        feeBps: BigInt(0),
        positionUpdate: [
            POSITION_UPDATE_BASE_TEST_CASES[
                POSITION_UPDATE_BASE_TEST_CASES.length - 1
            ],
        ],
    },
    {
        description:
            'price 1500, feeBps 0, positionUpdate price 1500, amount -10, feeBps 100',
        price: BigInt(1500),
        feeBps: BigInt(0),
        positionUpdate: [
            POSITION_UPDATE_BASE_TEST_CASES[
                POSITION_UPDATE_BASE_TEST_CASES.length - 1
            ],
        ],
    },
    {
        description:
            'price 0, feeBps 10, positionUpdate price 1500, amount -10, feeBps 100',
        price: BigInt(0),
        feeBps: BigInt(10),
        positionUpdate: [
            POSITION_UPDATE_BASE_TEST_CASES[
                POSITION_UPDATE_BASE_TEST_CASES.length - 1
            ],
        ],
    },
    {
        description:
            'price 1500, feeBps 10, positionUpdate price 1500, amount -10, feeBps 100',
        price: BigInt(1500),
        feeBps: BigInt(10),
        positionUpdate: [
            POSITION_UPDATE_BASE_TEST_CASES[
                POSITION_UPDATE_BASE_TEST_CASES.length - 1
            ],
        ],
    },
]

const limitCase: PositionLiquidateTestCase[] = [
    // positive values
    {
        description: 'price 0, feeBps 0, positionUpdate',
        price: BigInt(0),
        feeBps: BigInt(0),
        positionUpdate: [],
    },
    {
        description: 'price 0, feeBps 10000, positionUpdate',
        price: BigInt(0),
        feeBps: BigInt(10_000),
        positionUpdate: [],
    },
    {
        description: 'price 10**13, feeBps 0, positionUpdate',
        price: BigInt(10 ** 13),
        feeBps: BigInt(0),
        positionUpdate: [],
    },
    {
        description: 'price 10**13, feeBps 10000, positionUpdate',
        price: BigInt(10 ** 13),
        feeBps: BigInt(10_000),
        positionUpdate: [],
    },
]

let temp: PositionLiquidateTestCase[] = []

for (const casLiq of limitCase) {
    for (const casUp of POSITION_UPDATE_LIMIT_TEST_CASES) {
        temp.push({
            description: casLiq.description + casUp[0].description,
            price: casLiq.price,
            feeBps: casLiq.feeBps,
            positionUpdate: casUp,
        })
    }
}
const POSITION_LIQUIDATE_LIMIT_TEST_CASES: PositionLiquidateTestCase[] = temp

export {
    POSITION_LIQUIDATE_BASE_TEST_CASES,
    POSITION_LIQUIDATE_LIMIT_TEST_CASES,
}
