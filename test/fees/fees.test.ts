import { StarknetContract, StarknetContractFactory, StringMap } from "hardhat/types/runtime";
import {expect} from 'chai'
import {starknet} from 'hardhat'

import {CALCULATE_FEES_TEST_CASES_BASE, CALCULATE_FEES_TEST_CASES_FAIL, CALCULATE_FEES_TEST_CASES_LIMIT} from './test-cases/calculate-fees-test-cases'

const CONTRACT_PATH = 'test/fees.test.cairo'

let contract: StarknetContract

before(async () => {
    const ContractFactory: StarknetContractFactory = await starknet.getContractFactory(CONTRACT_PATH);
    contract = await ContractFactory.deploy();
})

async function compute_fee_bps(price: bigint, amount: bigint, long: bigint, short: bigint, liquidity: bigint) {
    const args: StringMap = {price, amount, long, short, liquidity}
    await contract.invoke('compute_fee_bps_test', args)
}

describe('#calculate_fee_bps', async () => {
    for (const testData of CALCULATE_FEES_TEST_CASES_BASE) {
        it(`should pass for each base case: ${testData.description}`, async () => {
            await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
            const result = await contract.call('get_fee_bps')
            const nominator: bigint = testData.price * testData.amount * (BigInt(2) * testData.long + (testData.price * testData.amount) - BigInt(2) * testData.short)
            const denominator: bigint = BigInt(2) * testData.liquidity
            const fee_bps: bigint = nominator/denominator
            expect(result.res).to.equal(fee_bps)
        })

    // for (const testData of CALCULATE_FEES_TEST_CASES_FAIL) {
    //     it(`should fail for each case: ${testData.description}`, async () => {
    //     try {
    //         await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
    //         expect.fail(`should have failed`)
    //     }
    //     catch(error: any) {
    //         expect(error.message).to.contain(testData.error, testData.description)
    //     }
    //     })
    // }

    //for (const testData of CALCULATE_FEES_TEST_CASES_LIMIT) {
        //it(`should pass for each limit case: ${testData.description}`, async () => {
            //await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
            //const result = await contract.call('get_fee_bps')
            //const nominator: bigint = testData.price * testData.amount * (BigInt(2) * testData.long + (testData.price * testData.amount) - BigInt(2) * testData.short)
            //const denominator: bigint = BigInt(2) * testData.liquidity
            //const fee_bps: bigint = nominator/denominator
            //console.log(fee_bps)
            //expect(result.res).to.equal(fee_bps)
        //})

   }
})
