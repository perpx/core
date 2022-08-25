import {
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import { REWARD_LIMIT_CASES } from './test-cases/simple-reward-test-cases'

let contract: StarknetContract

// constants
const INSTRUMENT: bigint = 1n
const address: bigint = BigInt(
    '0x60adf7d4250d8f1bc5b380381219b0e7b964dd9017ee95a932ac69eff4300d4'
)

//utils
async function check(
    address: bigint,
    instrument: bigint,
    liquidity: bigint,
    shares: bigint,
    userLiquidity: bigint,
    userShares: bigint
) {
    // liquidity
    const resLiq = await contract.call('view_liquidity', {
        instrument: instrument,
    })
    expect(resLiq.liquidity).to.equal(liquidity, 'failed on liquidity')
    // user liquidity
    const resUserLiq = await contract.call('view_user_liquidity', {
        owner: address,
        instrument: 1n,
    })
    expect(resUserLiq.liquidity).to.equal(
        userLiquidity,
        'failed on user liquidity'
    )
    // shares
    const resShares = await contract.call('view_shares', {
        instrument: instrument,
    })
    expect(resShares.shares).to.equal(shares, 'failed on shares')
    // user shares
    const resUserShares = await contract.call('view_user_shares', {
        owner: address,
        instrument: instrument,
    })
    expect(resUserShares.shares).to.equal(userShares, 'failed on user shares')
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/rewards_test.cairo')
    contract = await contractFactory.deploy()
})

describe('#update', () => {
    it('should pass for all limit cases', async () => {
        let liquidity: bigint = 0n
        let shares: bigint = 0n
        for (const scenario of REWARD_LIMIT_CASES) {
            for (const cas of scenario) {
                const args: StringMap = {
                    amount: cas.amount,
                    address: address,
                    instrument: INSTRUMENT,
                }
                await contract.invoke('provide_liquidity_test', args)
                // update values
                if (shares == 0n) {
                    shares = cas.amount * 100n
                } else {
                    const inc: bigint = (cas.amount * shares) / liquidity
                    shares += inc
                }
                liquidity += cas.amount
                check(address, INSTRUMENT, liquidity, shares, liquidity, shares)
            }
        }
    })
})
