interface VaultTestCase {
    description: string
    amount: bigint
    error?: string
}

const MAX_LIQUIDITY = BigInt(2 ** 64)

const VAULT_PROVIDE_LIMIT_CASES: VaultTestCase[][] = [
    [
        {
            description: 'amount 1, runs twice',
            amount: BigInt(1),
        },
        {
            description: 'amount MAX_LIQUIDITY/100 - 1, runs twice',
            amount: MAX_LIQUIDITY / 100n - 1n,
        },
    ],
    [
        {
            description: 'amount MAX_LIQUIDITY/100 - 1, runs twice',
            amount: MAX_LIQUIDITY / 100n - BigInt(1),
        },
        {
            description: 'amount 1, runs twice',
            amount: BigInt(1),
        },
    ],
    [
        {
            description: 'amount MAX_LIQUIDITY/200, runs twice',
            amount: MAX_LIQUIDITY / 200n,
        },
        {
            description: 'amount MAX_LIQUIDITY/200, runs twice',
            amount: MAX_LIQUIDITY / 200n,
        },
    ],
]

const VAULT_WITHDRAW_LIMIT_CASES: VaultTestCase[][] = [
    [
        {
            description: 'provide amount MAX_LIQUIDITY/100',
            amount: MAX_LIQUIDITY / 100n,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY/100',
            amount: (-1n * MAX_LIQUIDITY) / 100n,
        },
    ],
    [
        {
            description: 'provide amount MAX_LIQUIDITY/100',
            amount: MAX_LIQUIDITY / 100n,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY/200',
            amount: (-1n * MAX_LIQUIDITY) / 200n,
        },
        {
            description: 'withdraw amount MAX_LIQUIDITY/200',
            amount: (-1n * MAX_LIQUIDITY) / 200n,
        },
    ],
]

export { VAULT_PROVIDE_LIMIT_CASES, VAULT_WITHDRAW_LIMIT_CASES }
