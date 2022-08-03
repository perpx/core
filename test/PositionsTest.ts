import {
    StarknetContract,
    StarknetContractFactory,
    StringMap,
} from 'hardhat/types/runtime'
import { expect } from 'chai'
import { starknet } from 'hardhat'

let contract: StarknetContract
before(async () => {
    const contractFactory: StarknetContractFactory =
        await starknet.getContractFactory('test/Positions_test.cairo')
    contract = await contractFactory.deploy()
})

describe('#update', () => {
    it('should pass with an update of the position', async () => {
        const address = 0x7cde936f47a2240ab1f8764f4dcce14b53af1a5751c33eb4ecbfd643239da5d
        const args: StringMap = { address: address }
        const pos = await contract.invoke('get_position_test', args)
        console.log(pos)
    })
})
