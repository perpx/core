import {
    Account,
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import {
    VAULT_PROVIDE_LIMIT_CASES,
    VAULT_WITHDRAW_LIMIT_CASES,
} from './test-cases/vault-test-cases'

let contract: StarknetContract
let account: Account

// constants
const INSTRUMENT: bigint = 1n
const provideAddress: bigint = BigInt(
    '0x60adf7d4250d8f1bc5b380381219b0e7b964dd9017ee95a932ac69eff4300d4'
)
const withdrawAddress: bigint = BigInt(
    '0x44cd43437e6efd23da1631301b102ef5a0f3e6e27c41c1aadd0f718ebe83e86'
)

//utils
async function check(
    address: bigint,
    instrument: bigint,
    liquidity: bigint,
    shares: bigint,
    userShares: bigint
) {
    // liquidity
    const resLiq = await contract.call('view_liquidity', {
        instrument: instrument,
    })
    expect(resLiq.liquidity).to.equal(liquidity, 'failed on liquidity')
    // shares
    const resShares = await contract.call('view_shares', {
        instrument: instrument,
    })
    expect(resShares.shares).to.equal(shares, 'failed on shares')
    // user liquidity and shares
    const resUserStake = await contract.call('view_user_stake', {
        owner: address,
        instrument: instrument,
    })
    expect(resUserStake.stake.shares).to.equal(
        userShares,
        'failed on user shares'
    )
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/vault_test.cairo')
    contract = await contractFactory.deploy()
    account = await starknet.deployAccount('OpenZeppelin')
})

describe('#provide_liquidity', () => {
    it('should pass for all limit cases', async () => {
        let liquidity: bigint = 0n
        let shares: bigint = 0n
        for (const scenario of VAULT_PROVIDE_LIMIT_CASES) {
            let amount: bigint = 0n
            for (const cas of scenario) {
                let args: StringMap = {
                    amount: cas.amount,
                    owner: provideAddress,
                    instrument: INSTRUMENT,
                }
                console.log(args)
                await account.invoke(contract, 'provide_liquidity_test', args)
                // update values
                if (shares == 0n) {
                    shares = cas.amount * 100n
                } else {
                    const inc: bigint = (cas.amount * shares) / liquidity
                    shares += inc
                }
                liquidity += cas.amount
                await check(
                    provideAddress,
                    INSTRUMENT,
                    liquidity,
                    shares,
                    shares
                )
                amount += cas.amount
            }
            // clean the shares
            let args: StringMap = {
                amount: amount,
                owner: provideAddress,
                instrument: INSTRUMENT,
            }
            liquidity = 0n
            shares = 0n
            await account.invoke(contract, 'withdraw_liquidity_test', args)
        }
    })
})

describe('#withdraw_liquidity', () => {
    it('should pass for all limit cases', async () => {
        for (const scenario of VAULT_WITHDRAW_LIMIT_CASES) {
            for (const cas of scenario) {
                const args: StringMap = {
                    amount: cas.amount < 0 ? -cas.amount : cas.amount,
                    owner: withdrawAddress,
                    instrument: INSTRUMENT,
                }
                if (cas.amount > 0n) {
                    await account.invoke(
                        contract,
                        'provide_liquidity_test',
                        args
                    )
                } else {
                    await account.invoke(
                        contract,
                        'withdraw_liquidity_test',
                        args
                    )
                }
            }
            await check(withdrawAddress, INSTRUMENT, 0n, 0n, 0n)
        }
    })
})
