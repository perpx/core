import {
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import {
    POSITION_UPDATE_BASE_TEST_CASES,
    POSITION_UPDATE_REVERT_TEST_CASES,
    POSITION_UPDATE_LIMIT_TEST_CASES,
} from './test-cases/PositionUpdateTestCases'
import {
    POSITION_LIQUIDATE_BASE_TEST_CASES_GENERAL,
    POSITION_LIQUIDATE_BASE_TEST_CASES_SHORT,
    POSITION_LIQUIDATE_LIMIT_TEST_CASES,
    PositionLiquidateTestCase,
} from './test-cases/PositionLiquidateTestCases'

let contract: StarknetContract
let address: bigint
let prime: bigint
let POSITION_LIQUIDATE_BASE_TEST_CASES: PositionLiquidateTestCase[]
// Use short in order to test 8 of the 108 liquidation cases (only cases where price, amount fee_bsp != 0)
const short: boolean = true

function abs(num: bigint): bigint {
    return num < 0n ? -num : num
}

async function getPosition(address: BigInt) {
    const args: StringMap = {
        address: address,
        instrument: 0,
    }
    const pos = await contract.call('get_position_test', args)
    return pos
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/position_test.cairo')
    contract = await contractFactory.deploy()
    address = BigInt(
        '0x7cde936f47a2240ab1f8764f4dcce14b53af1a5751c33eb4ecbfd643239da5d'
    )
    prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
    POSITION_LIQUIDATE_BASE_TEST_CASES =
        POSITION_LIQUIDATE_BASE_TEST_CASES_GENERAL
    if (short) {
        POSITION_LIQUIDATE_BASE_TEST_CASES =
            POSITION_LIQUIDATE_BASE_TEST_CASES_SHORT
    }
})

describe('#update', () => {
    it('should pass with an empty position', async () => {
        const pos = await getPosition(address)
        expect(pos.position.fees).to.equal(0n)
        expect(pos.position.cost).to.equal(0n)
        expect(pos.position.size).to.equal(0n)
    })
    it('should pass with for each base case', async () => {
        for (const baseCase of POSITION_UPDATE_BASE_TEST_CASES) {
            const args: StringMap = {
                address: address,
                instrument: 0,
                price: baseCase.price,
                amount: baseCase.amount,
                fee_bps: baseCase.feeBps,
            }
            await contract.invoke('update_test', args)
            const pos = await getPosition(address)
            const cost = baseCase.amount * baseCase.price
            const fees = (abs(cost) * baseCase.feeBps) / 1_000_000n
            expect(pos.position.fees).to.equal(fees, 'failed on fees')
            expect(pos.position.cost).to.equal(cost, 'failed on cost')
            expect(pos.position.size).to.equal(
                baseCase.amount,
                'failed on size'
            )
            const arg: StringMap = {
                address: address,
                instrument: 0,
                price: 0n,
                fee_bps: 0n,
            }
            await contract.invoke('close_test', arg)
        }
    })
    it('should pass with for each limit case', async () => {
        for (const limitCase of POSITION_UPDATE_LIMIT_TEST_CASES) {
            let size: bigint = 0n
            let cost: bigint = 0n
            let fees: bigint = 0n
            for (const cas of limitCase) {
                const args: StringMap = {
                    address: address,
                    instrument: 0,
                    price: cas.price,
                    amount: cas.amount,
                    fee_bps: cas.feeBps,
                }
                await contract.invoke('update_test', args)
                const pos = await getPosition(address)
                size += BigInt(cas.amount)
                const costInc = cas.amount * cas.price
                cost += costInc
                fees += (abs(costInc) * cas.feeBps) / 1_000_000n
                if (pos.position.cost > prime / BigInt(2)) {
                    pos.position.cost = pos.position.cost - prime
                }
                if (pos.position.fees > prime / BigInt(2)) {
                    pos.position.fees = pos.position.fees - prime
                }
                if (pos.position.size > prime / BigInt(2)) {
                    pos.position.size = pos.position.size - prime
                }
                expect(pos.position.fees).to.deep.equal(
                    fees,
                    `failed on fees ${cas.description}`
                )
                expect(pos.position.cost).to.equal(
                    cost,
                    `failed on cost ${cas.description}`
                )
                expect(pos.position.size).to.equal(
                    size,
                    `failed on size ${cas.description}`
                )
            }
            const arg: StringMap = {
                address: address,
                instrument: 0,
                price: 0,
                fee_bps: 0,
            }
            await contract.invoke('close_test', arg)
        }
    })

    it('should fail for each revert case', async () => {
        for (const failScenario of POSITION_UPDATE_REVERT_TEST_CASES) {
            let args: StringMap
            let index: number = 0
            let passed: boolean = false
            for (let i = 0; failScenario[i].error === ''; i++) {
                args = {
                    address: address,
                    instrument: 0,
                    price: failScenario[i].price,
                    amount: failScenario[i].amount,
                    fee_bps: failScenario[i].feeBps,
                }
                await contract.invoke('update_test', args)
                index = i + 1
                passed = true
            }
            try {
                args = {
                    address: address,
                    instrument: 0,
                    price: failScenario[index].price,
                    amount: failScenario[index].amount,
                    fee_bps: failScenario[index].feeBps,
                }
                await contract.invoke('update_test', args)
                expect.fail(
                    `should have failed with ${failScenario[index].description}`
                )
            } catch (error: any) {
                expect(error.message).to.contain(
                    failScenario[index].error,
                    failScenario[index].description
                )
            }
            if (passed) {
                args = {
                    address: address,
                    instrument: 0,
                    price: 0,
                    fee_bps: 0,
                }
                await contract.invoke('close_test', args)
                passed = false
            }
        }
    })
})

// liquidate calls settle
describe('#liquidate #settle', () => {
    it('should pass for all base cases', async () => {
        for (const baseCase of POSITION_LIQUIDATE_BASE_TEST_CASES) {
            let size: bigint = BigInt(0)
            let cost: bigint = BigInt(0)
            let fees: bigint = BigInt(0)
            for (const update of baseCase.positionUpdate) {
                const args: StringMap = {
                    address: address,
                    instrument: 0,
                    price: update.price,
                    amount: update.amount,
                    fee_bps: update.feeBps,
                }
                await contract.invoke('update_test', args)
                size += update.amount
                const costInc: bigint = update.price * update.amount
                cost += costInc
                fees += (abs(costInc) * update.feeBps) / 1_000_000n
            }
            const args: StringMap = {
                address: address,
                instrument: 0,
                price: baseCase.price,
                fee_bps: baseCase.feeBps,
            }
            await contract.invoke('close_test', args)
            const costInc: bigint = -size * baseCase.price
            cost += costInc
            fees += (abs(costInc) * baseCase.feeBps) / 1_000_000n
            const delta = -cost - fees
            const resp = await contract.call('get_delta_test')
            expect(resp.delt).to.equal(delta)
        }
    })

    it('should pass for all limit cases', async () => {
        for (const limitCase of POSITION_LIQUIDATE_LIMIT_TEST_CASES) {
            let size: bigint = BigInt(0)
            let cost: bigint = BigInt(0)
            let fees: bigint = BigInt(0)
            for (const update of limitCase.positionUpdate) {
                const args: StringMap = {
                    address: address,
                    instrument: 0,
                    price: update.price,
                    amount: update.amount,
                    fee_bps: update.feeBps,
                }
                await contract.invoke('update_test', args)
                size += update.amount
                const costInc: bigint = update.price * update.amount
                cost += costInc
                fees += (abs(costInc) * update.feeBps) / 1_000_000n
            }
            const args: StringMap = {
                address: address,
                instrument: 0,
                price: limitCase.price,
                fee_bps: limitCase.feeBps,
            }
            await contract.invoke('close_test', args)
            const costInc: bigint = -size * limitCase.price
            cost += costInc
            fees += (abs(costInc) * limitCase.feeBps) / 1_000_000n
            const delta = -cost - fees
            const resp = await contract.call('get_delta_test')
            if (resp.delt > prime / BigInt(2)) {
                resp.delt = resp.delt - prime
            }
            expect(resp.delt).to.equal(delta)
        }
    })
})
