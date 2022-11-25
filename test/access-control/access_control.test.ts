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
let otherAccount: Account
let address: bigint
let prime: bigint

before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory(
            'contracts/test/access_control_test.cairo'
        )
    account = await starknet.deployAccount('OpenZeppelin')
    otherAccount = await starknet.deployAccount('OpenZeppelin')
    address = BigInt(account.address)
    contract = await contractFactory.deploy()
    prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
})

describe('#init_access_control', () => {
    it('should pass, init owner and emit OwnershipTransferred', async () => {
        const args: StringMap = {
            owner: account.address,
        }
        const txHash = await account.invoke(
            contract,
            'init_access_control_test',
            args
        )
        const res: StringMap = await contract.call('get_owner_test')
        expect(res.owner).to.equal(address)

        const receipt = await starknet.getTransactionReceipt(txHash)
        const events = await contract.decodeEvents(receipt.events)
        expect(events).to.deep.equal([
            {
                name: 'OwnershipTransferred',
                data: {
                    previousOwner: 0n,
                    newOwner: address,
                },
            },
        ])
    })
})

describe('#assert_only_owner_test', () => {
    it('should fail with Ownable: caller is not the owner', async () => {
        try {
            await otherAccount.invoke(contract, 'assert_only_owner_test')
            expect.fail('should have failed')
        } catch (error: any) {
            expect(error.message).to.contain('Ownable: caller is not the owner')
        }
    })

    it('should pass and update storage', async () => {
        await account.invoke(contract, 'assert_only_owner_test')
        const resp: StringMap = await contract.call('get_update_test')
        expect(resp.update).to.equal(1n)
    })
})
