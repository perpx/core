import {
    StarknetContract,
    Account,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import {
    INSTRUMENT_LONGS_LIMIT_CASES,
    INSTRUMENT_SHORTS_LIMIT_CASES,
    INSTRUMENT_LONGS_REVERT_CASES,
    INSTRUMENT_SHORTS_REVERT_CASES,
} from './test-cases/perpx-v1-instrument-test-cases'

let contract: StarknetContract
let account: Account

// constants
const INSTRUMENT: bigint = 1n

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/perpx_v1_instrument_test.cairo')
    contract = await contractFactory.deploy()
    account = await starknet.deployAccount('OpenZeppelin')
})

describe('#update_long_short', () => {
    it('should pass for all longs limit cases', async () => {
        let longs: bigint = 0n
        for (const scenario of INSTRUMENT_LONGS_LIMIT_CASES) {
            for (const cas of scenario) {
                const args: StringMap = {
                    amount: cas.amount,
                    instrument: INSTRUMENT,
                    is_long: 1,
                }
                await account.invoke(contract, 'update_long_short_test', args)
                longs += cas.amount
                const args_view: StringMap = {
                    instrument: INSTRUMENT,
                }
                const res = await contract.call('view_longs', args_view)
                expect(res.longs).to.equal(longs)
            }
        }
    })

    it('should revert on all cases with negative longs', async () => {
        for (const scenario of INSTRUMENT_LONGS_REVERT_CASES) {
            const args: StringMap = {
                amount: scenario.amount,
                instrument: INSTRUMENT,
                is_long: 1,
            }
            try {
                await account.invoke(contract, 'update_long_short_test', args)
                expect.fail('should have failed with negative longs')
            } catch (error: any) {
                expect(error.message).to.contain('negative longs')
            }
        }
    })
})

describe('#update_long_short', () => {
    it('should pass for all shorts limit cases', async () => {
        let shorts: bigint = 0n
        for (const scenario of INSTRUMENT_SHORTS_LIMIT_CASES) {
            for (const cas of scenario) {
                const args: StringMap = {
                    amount: cas.amount,
                    instrument: INSTRUMENT,
                    is_long: 0,
                }
                await account.invoke(contract, 'update_long_short_test', args)
                shorts += cas.amount
                const args_view: StringMap = {
                    instrument: INSTRUMENT,
                }
                const res = await contract.call('view_shorts', args_view)
                expect(res.shorts).to.equal(shorts)
            }
        }
    })

    it('should revert on all cases with negative shorts', async () => {
        for (const scenario of INSTRUMENT_SHORTS_REVERT_CASES) {
            const args: StringMap = {
                amount: scenario.amount,
                instrument: INSTRUMENT,
                is_long: 0,
            }
            try {
                await account.invoke(contract, 'update_long_short_test', args)
                expect.fail('should have failed with negative shorts')
            } catch (error: any) {
                expect(error.message).to.contain('negative shorts')
            }
        }
    })
})
