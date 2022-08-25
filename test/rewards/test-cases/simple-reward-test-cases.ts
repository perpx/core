interface RewardTestCase {
    description: string
    amount: bigint
    error?: string
}

const MAX_LIQUIDITY = BigInt(2 ** 64)

const REWARD_LIMIT_CASES: RewardTestCase[][] = [
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

export { REWARD_LIMIT_CASES }
