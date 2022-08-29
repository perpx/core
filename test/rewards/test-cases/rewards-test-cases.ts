interface RewardTestCase {
    description: string
    amount: bigint
    error?: string
}

const MAX_LIQUIDITY = BigInt(2 ** 64)

const REWARD_PROVIDE_LIMIT_CASES: RewardTestCase[][] = [
    [
        {
            description: 'amount 1, runs twice',
            amount: BigInt(1),
        },
        {
            description: 'amount MAX_LIQUIDITY - 1, runs twice',
            amount: MAX_LIQUIDITY - BigInt(1),
        },
    ],
    [
        {
            description: 'amount MAX_LIQUIDITY - 1, runs twice',
            amount: MAX_LIQUIDITY - BigInt(1),
        },
        {
            description: 'amount 1, runs twice',
            amount: BigInt(1),
        },
    ],
    [
        {
            description: 'amount MAX_LIQUIDITY/2, runs twice',
            amount: MAX_LIQUIDITY / 2n,
        },
        {
            description: 'amount MAX_LIQUIDITY/2, runs twice',
            amount: MAX_LIQUIDITY / 2n,
        },
    ],
]

const REWARD_WITHDRAW_LIMIT_CASES: RewardTestCase[][] = [
    [
        {
            description: 'provide amount MAX_LIQUIDITY',
            amount: MAX_LIQUIDITY,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY',
            amount: -1n * MAX_LIQUIDITY,
        },
    ],
    [
        {
            description: 'provide amount MAX_LIQUIDITY',
            amount: MAX_LIQUIDITY,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY/2',
            amount: (-1n * MAX_LIQUIDITY) / 2n,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY/2',
            amount: (-1n * MAX_LIQUIDITY) / 2n,
        },
    ],
]

export { REWARD_PROVIDE_LIMIT_CASES, REWARD_WITHDRAW_LIMIT_CASES }
