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
let address: bigint
let prime: bigint

async function getPosition(address: BigInt) {
    const args: StringMap = { address: address }
    const pos = await contract.call('get_position', args)
    return pos
}

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory(
            'contracts/test/access_control_test.cairo'
        )
    account = await starknet.deployAccount('OpenZeppelin')
    address = BigInt(account.address)
    contract = await contractFactory.deploy()
    prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
})

describe('#init_access_control', () => {
    it('should fail with owner cannot be the zero address', async () => {
        const args: StringMap = {
            owner: BigInt(0),
        }
        try {
            await contract.invoke('init_access_control_test', args)
            expect.fail('should have failed')
        } catch (error: any) {
            expect(error.message).to.contain('owner cannot be the zero address')
        }
    })

    it('should pass, init owner and emit access_control_initialized', async () => {
        const args: StringMap = {
            owner: account.address,
        }
        const txHash = await contract.invoke('init_access_control_test', args)
        const res: StringMap = await contract.call('get_owner_test')
        expect(res.owner).to.equal(address)

        const receipt = await starknet.getTransactionReceipt(txHash)
        const events = await contract.decodeEvents(receipt.events)
        expect(events).to.deep.equal([
            {
                name: 'access_control_initialized',
                data: {
                    owner: address,
                },
            },
        ])
    })
})

describe('#only_owner_test', () => {
    it('should fail with callable limited to owner', async () => {
        try {
            await contract.invoke('only_owner_test')
            expect.fail('should have failed')
        } catch (error: any) {
            expect(error.message).to.contain('callable limited to owner')
        }
    })

    it('should pass and update storage', async () => {
        await account.invoke(contract, 'only_owner_test')
        const resp: StringMap = await contract.call('get_update_test')
        expect(resp.update).to.equal(1n)
    })
})
