import {
    PositionUpdateTestCase,
    POSITION_UPDATE_BASE_TEST_CASES,
    POSITION_UPDATE_LIMIT_TEST_CASES,
} from './PositionUpdateTestCases'

interface PositionLiquidateTestCase {
    description: string
    positionUpdate: PositionUpdateTestCase[]
    price: bigint
    fees: bigint
    error?: string
}

const priceLiq: bigint[] = [0n, 1_500n]
const feeLiq: bigint[] = [-10_000n, 0n, 10_000n]
const priceUpdate: bigint[] = [0n, 1_500n]
const amountUpdate: bigint[] = [-10n, 0n, 10n]
const feeUpdate: bigint[] = [-10_000n, 0n, 10_000n]

let tempLiqBase: PositionLiquidateTestCase[] = []
for (const pLiq of priceLiq) {
    for (const fLiq of feeLiq) {
        for (const pUp of priceUpdate) {
            for (const aUp of amountUpdate) {
                for (const fUp of feeUpdate) {
                    tempLiqBase.push({
                        description: `price ${pLiq}, fees ${fLiq}, positionUpdate price ${pUp}, amount ${aUp}, fees ${fUp}`,
                        price: pLiq,
                        fees: fLiq,
                        positionUpdate: [
                            {
                                description: `price ${pUp}, amount ${aUp}, fees ${fUp}`,
                                price: pUp,
                                amount: aUp,
                                fees: fUp,
                            },
                        ],
                    })
                }
            }
        }
    }
}

const POSITION_LIQUIDATE_BASE_TEST_CASES_GENERAL: PositionLiquidateTestCase[] =
    tempLiqBase

const POSITION_LIQUIDATE_BASE_TEST_CASES_SHORT: PositionLiquidateTestCase[] = [
    // positive amount, positive fees, positive fees update
    {
        description:
            'price 1500, fees 10_000, positionUpdate price 1500, amount 10, fees 10_000',
        price: BigInt(1500),
        fees: BigInt(10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    // positive amount, positive fees, negative fees update
    {
        description:
            'price 1500, fees 10_000, positionUpdate price 1500, amount 10, fees -10_000',
        price: BigInt(1500),
        fees: BigInt(10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[15]],
    },
    // positive amount, negative fees, positive fees update
    {
        description:
            'price 1500, fees -10_000, positionUpdate price 1500, amount 10, fees 10_000',
        price: BigInt(1500),
        fees: BigInt(-10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[7]],
    },
    // positive amount, negative fees, negative fees update
    {
        description:
            'price 1500, fees -10_000, positionUpdate price 1500, amount 10, fees -10_000',
        price: BigInt(1500),
        fees: BigInt(-10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[15]],
    },
    // negative amount, positive fees, positive fees update
    {
        description:
            'price 1500, fees 10_000, positionUpdate price 1500, amount -10, fees 10_000',
        price: BigInt(1500),
        fees: BigInt(10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[11]],
    },
    // negative amount, negative fees, positive fees update
    {
        description:
            'price 1500, fees -10_000, positionUpdate price 1500, amount -10, fees 10_000',
        price: BigInt(1500),
        fees: BigInt(-10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[11]],
    },
    // negative amount, positive fees, negative fees update
    {
        description:
            'price 1500, fees 10_000, positionUpdate price 1500, amount -10, fees -10_000',
        price: BigInt(1500),
        fees: BigInt(10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[17]],
    },
    // negative amount, negative fees, negative fees update
    {
        description:
            'price 1500, fees -10_000, positionUpdate price 1500, amount -10, fees -10_000',
        price: BigInt(1500),
        fees: BigInt(-10_000),
        positionUpdate: [POSITION_UPDATE_BASE_TEST_CASES[17]],
    },
]

const limitCase: PositionLiquidateTestCase[] = [
    // positive values
    {
        description: 'price 0, fees 0, positionUpdate',
        price: BigInt(0),
        fees: BigInt(0),
        positionUpdate: [],
    },
    {
        description: 'price 0, fees 1_000_000, positionUpdate',
        price: BigInt(0),
        fees: BigInt(1_000_000),
        positionUpdate: [],
    },
    {
        description: 'price 10**13, fees 0, positionUpdate',
        price: BigInt(10 ** 13),
        fees: BigInt(0),
        positionUpdate: [],
    },
    {
        description: 'price 10**13, fees 1_000_000, positionUpdate',
        price: BigInt(10 ** 13),
        fees: BigInt(1_000_000),
        positionUpdate: [],
    },
    // negative values
    {
        description: 'price 0, fees -1_000_000, positionUpdate',
        price: BigInt(0),
        fees: BigInt(-1_000_000),
        positionUpdate: [],
    },
    {
        description: 'price 10**13, fees -1_000_000, positionUpdate',
        price: BigInt(10 ** 13),
        fees: BigInt(-1_000_000),
        positionUpdate: [],
    },
]

let temp: PositionLiquidateTestCase[] = []

for (const casLiq of limitCase) {
    for (const casUp of POSITION_UPDATE_LIMIT_TEST_CASES) {
        temp.push({
            description: casLiq.description + casUp[0].description,
            price: casLiq.price,
            fees: casLiq.fees,
            positionUpdate: casUp,
        })
    }
}
const POSITION_LIQUIDATE_LIMIT_TEST_CASES: PositionLiquidateTestCase[] = temp

export {
    POSITION_LIQUIDATE_BASE_TEST_CASES_GENERAL,
    POSITION_LIQUIDATE_BASE_TEST_CASES_SHORT,
    POSITION_LIQUIDATE_LIMIT_TEST_CASES,
    PositionLiquidateTestCase,
}
