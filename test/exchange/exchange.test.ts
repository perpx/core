import {
    Account,
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'
import { DeployOptions } from '@shardlabs/starknet-hardhat-plugin/dist/src/types'

let deployer: StarknetContract
let contract: StarknetContract

let account: Account
let otherAccount: Account

const limit: number = 1_000_000_000
const INSTRUMENTS_AMOUNT: number = 10

function getOneBits(n: number) {
    var count = 0
    var mask = 1
    for (let i = 0; i < 32; i++) {
        if ((mask & n) != 0) {
            count++
        }
        mask <<= 1
    }
    return count
}

function generateNBitsWord(n: number, limit: number) {
    let bits: number[] = []
    let num = 0
    while (n > 0) {
        let bit = Math.floor(Math.random() * limit)
        if (!bits.includes(bit)) {
            n--
            bits.push(bit)
            num += 1 << bit
        }
    }
    return num
}

describe('PerpxV1Exchange', () => {
    before(async () => {
        // get contract class hash
        const contractFactory: StarknetContractFactory =
            await starknet.getContractFactory(
                'contracts/test/perpx_v1_exchange_test.cairo'
            )
        const classHash: string = await contractFactory.declare()

        // deploy deployer contract
        const deployerFactory: StarknetContractFactory =
            await starknet.getContractFactory('contracts/utils/deployer.cairo')
        const deployOpts: DeployOptions = {
            salt: '0x124',
        }
        deployer = await deployerFactory.deploy({}, deployOpts)

        // deploy accounts
        account = await starknet.deployAccount('OpenZeppelin')
        otherAccount = await starknet.deployAccount('OpenZeppelin')

        // call deploy_contract from deployer
        const args: StringMap = {
            args: [INSTRUMENTS_AMOUNT],
            class_hash: classHash,
            has_owner: 1,
        }
        const txHash = await account.invoke(deployer, 'deploy_contract', args)
        const receipt = await starknet.getTransactionReceipt(txHash)
        contract = contractFactory.getContractAt(receipt.events[1].data[0])
    })

    describe('#update_prices', () => {
        it('should fail with callable limited to owner', async () => {
            const args: StringMap = {
                prices: [],
                instruments: BigInt(0),
            }
            try {
                await otherAccount.invoke(contract, 'update_prices_test', args)
                expect.fail('should have failed with wrong owner')
            } catch (error: any) {
                expect(error.message).to.contain('callable limited to owner')
            }
        })

        it('should fail with assert_eq instruction failure', async () => {
            const maxNumber: number = 2 ** INSTRUMENTS_AMOUNT
            const iterations: number = 20
            let i: number = 0
            while (i < iterations) {
                let length = Math.floor(Math.random() * INSTRUMENTS_AMOUNT)
                let instruments = Math.floor(Math.random() * maxNumber)
                if (length == getOneBits(instruments)) {
                    continue
                }
                let args: StringMap = {
                    prices: Array.from({ length: length }, () =>
                        Math.floor(Math.random() * limit)
                    ),
                    instruments: BigInt(instruments),
                }
                try {
                    await account.invoke(contract, 'update_prices_test', args)
                    expect.fail('should have failed with length error')
                } catch (error: any) {
                    expect(error.message).to.contain(
                        'An ASSERT_EQ instruction failed'
                    )
                }
                i++
            }
        })

        it('it should pass and update the prices', async () => {
            const iterations: number = 20
            let i: number = 0
            while (i < iterations) {
                let length = Math.floor(Math.random() * INSTRUMENTS_AMOUNT)
                let instruments = BigInt(
                    generateNBitsWord(length, INSTRUMENTS_AMOUNT - 1)
                )
                let prices: number[] = Array.from({ length: length }, () =>
                    Math.floor(Math.random() * limit)
                )
                let args: StringMap = {
                    prices: prices,
                    instruments: instruments,
                }
                await account.invoke(contract, 'update_prices_test', args)
                let mult = 1
                let index = 0
                while (instruments > 0n) {
                    let r = instruments % 2n
                    if (r == 1n) {
                        const res = await contract.call('view_price_test', {
                            instrument: mult,
                        })
                        expect(res.price).to.equal(BigInt(prices[index]))
                        index += 1
                    }
                    instruments >>= 1n
                    mult <<= 1
                }
                i++
            }
        })
    })
})
