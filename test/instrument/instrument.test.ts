import {
    Account,
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'

let contract: StarknetContract
let account: Account
let exchange: Account
let exchangeAddress: bigint
let accountAddress: bigint
let prime: bigint

async function getPosition(address: BigInt) {
    const args: StringMap = { address: address }
    const pos = await contract.call('get_position', args)
    return pos
}

describe('PerpxV1Instrument', () => {
    before(async () => {
        const contractFactory: StarknetContractFactory =
            await starknet.getContractFactory(
                'contracts/perpx_v1_instrument.cairo'
            )
        account = await starknet.deployAccount('OpenZeppelin')
        accountAddress = BigInt(account.address)
        exchange = await starknet.deployAccount('OpenZeppelin')
        exchangeAddress = BigInt(exchange.address)
        const args: StringMap = {
            owner: account.address,
            exchange: exchangeAddress,
            _price: BigInt(1_000_000_000_000),
            _fee: BigInt(10_000),
        }
        contract = await contractFactory.deploy(args)
        prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
    })

    // settle, trade and liquidate are testes in position.test.ts
    describe('#get_position', () => {
        it('should pass with an empty position', async () => {
            const pos = await getPosition(accountAddress)
            expect(pos.position.fees).to.equal(0n)
            expect(pos.position.cost).to.equal(0n)
            expect(pos.position.size).to.equal(0n)
        })
    })
})
