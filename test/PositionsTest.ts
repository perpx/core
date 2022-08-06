import {
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import {
    POSITION_BASE_TEST_CASE,
    POSITION_REVERT_TEST_CASE,
    POSITION_LIMIT_TEST_CASE,
} from './PositionTestCases'
import { InvokeResponse } from '@shardlabs/starknet-hardhat-plugin/dist/src/types'

let contract: StarknetContract
let address: bigint
let prime: bigint

let maxPrice: bigint = BigInt(10 ** 13)
let rangeCheckBound: bigint = BigInt(2 ** 128)
let maxAmount: bigint = BigInt(2 ** 82)
let maxBound: bigint = BigInt(2 ** 127)

function abs(num: bigint): bigint {
    return num < 0n ? -num : num
}

async function getPosition(address: BigInt) {
    const args: StringMap = { address: address }
    const pos = await contract.call('get_position_test', args)
    return pos
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/positions_test.cairo')
    contract = await contractFactory.deploy()
    address = BigInt(
        '0x7cde936f47a2240ab1f8764f4dcce14b53af1a5751c33eb4ecbfd643239da5d'
    )
    prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
})

describe('#update', () => {
    it('it should pass with an empty position', async () => {
        const pos = await getPosition(address)
        expect(pos.position.fees).to.equal(0n)
        expect(pos.position.cost).to.equal(0n)
        expect(pos.position.size).to.equal(0n)
    })

    it('should pass with for each base case', async () => {
        for (const baseCase of POSITION_BASE_TEST_CASE) {
            const args: StringMap = {
                address: address,
                price: baseCase.price,
                amount: baseCase.amount,
                feeBps: baseCase.feeBps,
            }
            await contract.invoke('update_test', args)
            const pos = await getPosition(address)
            const cost = baseCase.amount * baseCase.price
            const fees = (abs(cost) * baseCase.feeBps) / 10_000n
            expect(pos.position.fees).to.equal(fees, 'failed on fees')
            expect(pos.position.cost).to.equal(cost, 'failed on cost')
            expect(pos.position.size).to.equal(
                baseCase.amount,
                'failed on size'
            )
            const arg: StringMap = {
                address: address,
                price: 0,
            }
            await contract.invoke('settle_test', arg)
        }
    })

    it('should pass with for each limit case', async () => {
        for (const limitCase of POSITION_LIMIT_TEST_CASE) {
            let size: bigint = 0n
            let cost: bigint = 0n
            let fees: bigint = 0n
            for (const cas of limitCase) {
                const args: StringMap = {
                    address: address,
                    price: cas.price,
                    amount: cas.amount,
                    feeBps: cas.feeBps,
                }
                await contract.invoke('update_test', args)
                const pos = await getPosition(address)
                size += BigInt(cas.amount)
                const costInc = BigInt(cas.amount * cas.price)
                cost += costInc
                fees += (abs(costInc) * cas.feeBps) / 10_000n
                expect(pos.position.fees).to.equal(
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
            console.log('settle')
            const arg: StringMap = {
                address: address,
                price: 0,
            }
            await contract.invoke('settle_test', arg)
        }
    })

    it('should fail for each base case', async () => {
        for (const failScenario of POSITION_REVERT_TEST_CASE) {
            let args: StringMap
            let index: number = 0
            let passed: boolean = false
            for (let i = 0; failScenario[i].error === ''; i++) {
                args = {
                    address: address,
                    price: failScenario[i].price,
                    amount: failScenario[i].amount,
                    feeBps: failScenario[i].feeBps,
                }
                await contract.invoke('update_test', args)
                index = i + 1
                passed = true
            }
            try {
                args = {
                    address: address,
                    price: failScenario[index].price,
                    amount: failScenario[index].amount,
                    feeBps: failScenario[index].feeBps,
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
                    price: 0,
                }
                await contract.invoke('settle_test', args)
                passed = false
            }
        }
    })
})
