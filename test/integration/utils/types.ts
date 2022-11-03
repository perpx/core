export interface Account {
    privateKey: string
}

export enum operation {
    OpenPosition,
    ClosePosition,
    AddCollateral,
    Liquidate,
    ProvideLiquidity,
    RemoveLiquidity,
}

export interface Operation {
    amount?: bigint
    margin?: bigint
    price?: bigint
    instrument?: bigint
    positionId?: bigint
    user?: string
    isLong?: boolean
    block: bigint
    type: operation
}
