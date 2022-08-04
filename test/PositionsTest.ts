import {
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'

let contract: StarknetContract
let address: BigInt

async function getPosition(address: BigInt) {
    const args: StringMap = { address: address }
    const pos = await contract.call('get_position_test', args)
    return pos
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/Positions_test.cairo')
    contract = await contractFactory.deploy()
    address = BigInt(
        '0x7cde936f47a2240ab1f8764f4dcce14b53af1a5751c33eb4ecbfd643239da5d'
    )
})

describe('#update', () => {
    it('it should pass with an empty position', async () => {
        const pos = await getPosition(address)
        expect(pos.position.fees).to.equal(0n)
        expect(pos.position.cost).to.equal(0n)
        expect(pos.position.size).to.equal(0n)
    })
    it('should pass with an update of the position', async () => {
        const price = BigInt(1_500_000_000) // price in USDC with 6 decimals
        const amount = BigInt(1)
        const feeBps = BigInt(100) // fees in bips
        const args: StringMap = {
            address: address,
            price: price,
            amount: amount,
            feeBps: feeBps,
        }
        await contract.invoke('update_test', args)
        const pos = await getPosition(address)
        expect(pos.position.fees).to.equal(15_000_000n)
        expect(pos.position.cost).to.equal(1_500_000_000n)
        expect(pos.position.size).to.equal(1n)
    })
})
