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
let otherAccountAddress: bigint
let accountAddress: bigint
let prime: bigint

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
    accountAddress = BigInt(account.address)
    otherAccount = await starknet.deployAccount('OpenZeppelin')
    otherAccountAddress = BigInt(otherAccount.address)

    // call deploy_contract from deployer
    const args: StringMap = {
        args: [10],
        class_hash: classHash,
    }
    const txHash = await account.invoke(deployer, 'deploy_contract', args)
    const receipt = await starknet.getTransactionReceipt(txHash)
    contract = contractFactory.getContractAt(receipt.events[1].data[0])

    prime = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)
})

describe('#update_prices', () => {
    it('should fail with callable limited to owner', async () => {
        const args: StringMap = {
            prices: [1000, 129, 124, 1],
            instruments:
                BigInt(2 ** 8) +
                BigInt(2 ** 6) +
                BigInt(2 ** 5) +
                BigInt(2 ** 2),
        }
        try {
            await otherAccount.invoke(contract, 'update_prices_test', args)
            expect.fail('should have failed with wrong owner')
        } catch (error: any) {
            expect(error.message).to.contain('callable limited to owner')
        }
    })
})
