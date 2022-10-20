import {
    Account,
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import {
    POSITION_UPDATE_BASE_TEST_CASES,
    POSITION_UPDATE_LIMIT_TEST_CASES,
} from './test-cases/PositionUpdateTestCases'
import {
    POSITION_LIQUIDATE_BASE_TEST_CASES_GENERAL,
    POSITION_LIQUIDATE_BASE_TEST_CASES_SHORT,
    POSITION_LIQUIDATE_LIMIT_TEST_CASES,
    PositionLiquidateTestCase,
} from './test-cases/PositionLiquidateTestCases'

let contract: StarknetContract
let account: Account
let address: bigint
let prime: bigint
let POSITION_LIQUIDATE_BASE_TEST_CASES: PositionLiquidateTestCase[]
const INSTRUMENT = 2
// Use short in order to test 8 of the 108 liquidation cases (only cases where price, amount fee_bsp != 0)
const short: boolean = true

async function getPosition(address: BigInt) {
    const args: StringMap = { owner: address, instrument: INSTRUMENT }
    return await contract.call('get_position_test', args)
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/position_test.cairo')
    contract = await contractFactory.deploy()
    account = await starknet.deployAccount('OpenZeppelin')
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
                owner: address,
                price: baseCase.price,
                amount: baseCase.amount,
                fees: baseCase.fees,
                instrument: INSTRUMENT,
            }
            await account.invoke(contract, 'update_test', args)
            const pos = await getPosition(address)
            const cost = baseCase.amount * baseCase.price
            const fees = baseCase.fees
            expect(pos.position.fees).to.equal(fees, 'failed on fees')
            expect(pos.position.cost).to.equal(cost, 'failed on cost')
            expect(pos.position.size).to.equal(
                baseCase.amount,
                'failed on size'
            )
            const arg: StringMap = {
                owner: address,
                price: 0n,
                fees: 0n,
                instrument: INSTRUMENT,
            }
            await account.invoke(contract, 'close_test', arg)
        }
    })
    it('should pass with for each limit case', async () => {
        for (const limitCase of POSITION_UPDATE_LIMIT_TEST_CASES) {
            let size: bigint = 0n
            let cost: bigint = 0n
            let fees: bigint = 0n
            for (const cas of limitCase) {
                const args: StringMap = {
                    owner: address,
                    price: cas.price,
                    amount: cas.amount,
                    fees: cas.fees,
                    instrument: INSTRUMENT,
                }
                await account.invoke(contract, 'update_test', args)
                const pos = await getPosition(address)
                size += BigInt(cas.amount)
                const costInc = cas.amount * cas.price
                cost += costInc
                fees += cas.fees
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
                owner: address,
                price: 0,
                fees: 0,
                instrument: INSTRUMENT,
            }
            await account.invoke(contract, 'close_test', arg)
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
                    owner: address,
                    price: update.price,
                    amount: update.amount,
                    fees: update.fees,
                    instrument: INSTRUMENT,
                }
                await account.invoke(contract, 'update_test', args)
                size += update.amount
                const costInc: bigint = update.price * update.amount
                cost += costInc
                fees += update.fees
            }
            const args: StringMap = {
                owner: address,
                price: baseCase.price,
                fees: baseCase.fees,
                instrument: INSTRUMENT,
            }
            await account.invoke(contract, 'close_test', args)
            const costInc: bigint = -size * baseCase.price
            cost += costInc
            fees += baseCase.fees
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
                    owner: address,
                    price: update.price,
                    amount: update.amount,
                    fees: update.fees,
                    instrument: INSTRUMENT,
                }
                await account.invoke(contract, 'update_test', args)
                size += update.amount
                const costInc: bigint = update.price * update.amount
                cost += costInc
                fees += update.fees
            }
            const args: StringMap = {
                owner: address,
                price: limitCase.price,
                fees: limitCase.fees,
                instrument: INSTRUMENT,
            }
            await account.invoke(contract, 'close_test', args)
            const costInc: bigint = -size * limitCase.price
            cost += costInc
            fees += limitCase.fees
            const delta = -cost - fees
            const resp = await contract.call('get_delta_test')
            if (resp.delt > prime / BigInt(2)) {
                resp.delt = resp.delt - prime
            }
            expect(resp.delt).to.equal(delta)
        }
    })
})
