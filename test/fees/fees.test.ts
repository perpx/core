import { StarknetContract, StarknetContractFactory, StringMap } from "hardhat/types/runtime";
import {expect} from 'chai'
import {starknet} from 'hardhat'

import {CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED,
        CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED,
        CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED} from './test-cases/calculate-fees-test-cases'

// choose the tests to perform
const limit_case = false;
const base_case = false;
const fail_case = true;

const CONTRACT_PATH = 'test/fees_test.cairo'

const PRIME: bigint = BigInt(2 ** 251) + BigInt(17) * BigInt(2 ** 192) + BigInt(1)

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


    if (fail_case) {
    for (const testData of CALCULATE_FEES_TEST_CASES_FAIL_AUTOMATED) {
        it(`should fail for each fail case: ${testData.description}`, async () => {
            try {
                await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
                expect.fail("should have failed")
            }
            catch(error: any) {
                expect(error.message)
            } 
        })
    }
}


    if (limit_case) {
    for (const testData of CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED) {
        it(`should pass for each limit case: ${testData.description}`, async () => {
            await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
            const result = await contract.call('get_fee_bps')
            let cairo_fee_bps: bigint = result.res
            const nominator: bigint = testData.price * testData.amount * (BigInt(2) * testData.long + (testData.price * testData.amount) - BigInt(2) * testData.short)
            const denominator: bigint = BigInt(2) * testData.liquidity

            let hardhat_fee_bps:bigint = nominator/denominator
            let rest: bigint = nominator%denominator

            if (rest < 0n) { 
                hardhat_fee_bps += -1n
            }

            // for some negative numbers that are too high
            if ((result.res > PRIME/BigInt(2))) {
                console.log('cairo fees higher than PRIME')
                cairo_fee_bps = cairo_fee_bps - PRIME
            }
            console.log("hardhart: ", hardhat_fee_bps)
            console.log("cairo: ", cairo_fee_bps)
            expect(hardhat_fee_bps).to.equal(cairo_fee_bps)
        })
    }
}


    if (base_case) {
    for (const testData of CALCULATE_FEES_TEST_CASES_BASE_AUTOMATED) {
        it(`should pass for each base case: ${testData.description}`, async () => {
            await compute_fee_bps(testData.price, testData.amount, testData.long, testData.short, testData.liquidity)
            const result = await contract.call('get_fee_bps')
            let cairo_fee_bps: bigint = result.res
            const nominator: bigint = testData.price * testData.amount * (BigInt(2) * testData.long + (testData.price * testData.amount) - BigInt(2) * testData.short)
            const denominator: bigint = BigInt(2) * testData.liquidity

            let hardhat_fee_bps:bigint = nominator/denominator
            let rest: bigint = nominator%denominator

            if (rest < 0n) { 
                hardhat_fee_bps += -1n
            }

            // for some negative numbers that are too high
            if ((result.res > PRIME/BigInt(2))) {
                console.log('cairo fees higher than PRIME')
                cairo_fee_bps = cairo_fee_bps - PRIME
            }
            console.log("hardhart: ", hardhat_fee_bps)
            console.log("cairo: ", cairo_fee_bps)
            expect(hardhat_fee_bps).to.equal(cairo_fee_bps)
        })
    }
}
})
