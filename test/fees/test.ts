import {BigNumber} from 'ethers'
// console.log(`BigInt(1) * -BigInt(524287) * (BigInt(2) * BigInt(5242869999999475713) + (BigInt(1) * -BigInt(524287)))`)
// const nominator: bigint = BigInt(1) * -BigInt(524287) * (BigInt(2) * BigInt(5242869999999475713) + (BigInt(1) * -BigInt(524287)) - BigInt(2) * BigInt(0))
// const denominator: bigint = BigInt(2)*BigInt(1)

// const result: bigint = nominator/denominator

// console.log(result)
//import {CALCULATE_FEES_TEST_CASES_LIMIT_AUTOMATED} from './test-cases/calculate-fees-test-cases'

/*
const testData = {
    price: BigInt(1),
    amount: (-BigInt(2**19)),
    long: ((BigInt(10**13)-BigInt(1)) * (BigInt(2**19)-BigInt(1))),
    //long: BigInt(0),
    // liquidity: BigInt(1),
    liquidity: (BigInt(2**122) - BigInt(1)),
    // liquidity: BigInt(1),
    short: BigInt(0),
}

const nominator: bigint = testData.price * testData.amount * (BigInt(2) * testData.long + (testData.price * testData.amount) - BigInt(2) * testData.short)
const denominator: bigint = BigInt(2) * testData.liquidity
//const fee_bps: bigint = nominator/denominator
const fee_bps: bigint = nominator/denominator
const fee_bps_2: bigint = BigInt(Math.floor(Number(nominator)/Number(denominator)))
console.log('nom: ', nominator)
console.log('nom numb : ', Number(nominator))
console.log('denom : ', denominator)
console.log('denom numb : ', Number(denominator))
console.log('without floor : ', nominator/denominator)
// have to use Math.floor because with BigInt it does not do it well, it does the ceil and not floor.
console.log('with floor : ', BigInt(Math.floor(Number(nominator)/Number(denominator))))
// console.log(fee_bps_2);

const rest: bigint = nominator%denominator
//const fee_bps: bigint = (nominator + reste)/denominator
// console.log('price: ',testData.price);
// console.log('amount: ',testData.amount);
// console.log('reste: ', reste)
// console.log('nominator: ', nominator)
// console.log('denominator: ', denominator)
// console.log('rest: ', rest);
// console.log('new fee bps: ', new_fee_bps);
// console.log("hardhart without math.floor: ", fee_bps)
// console.log("hardhart with math.floor: ", fee_bps_2)
// */

/*
//result
// const q: bigint = -11398n
//denominator
const div: bigint = 460490684n

//rest
const cairo_r: bigint = 397140527n
const hardhat_r: bigint = -63350157n

// nominator
const value: bigint = -5248275675705n
// const hardhat_q: bigint = -11397n

// const PRIME: bigint = BigInt(2 ** 251 + 17 * 2 ** 192 + 1)

const hardhat_q:bigint = (value-hardhat_r)/div
const cairo_q:bigint = (value-cairo_r)/div

// const 
console.log(hardhat_q)
console.log(cairo_q)
*/


// # The prime is the range bound for felt on cairo


// const value: bigint = 493403400349n
// const div: bigint = 34095349n

// const math_floor


// const value: BigNumber = BigNumber.from(-5497547653119175367327744n)
// const div = BigNumber.from(2n)


function random_inside_limit(array: Array<BigInt>): Array<BigInt> {
    let a: BigInt = BigInt(Math.floor(Number(array[0])+Math.random()*Number(array[1])+1))
    let b: BigInt = BigInt(Math.floor(Number(array[1])-Math.random()*Number(array[1])+1))
    return [a,b]
}


const MAX_PRICE = 10**13
const MAX_AMOUNT = 2 ** 19
const MIN_LIQUIDITY = 1
const MAX_LIQUIDITY = 2**122

const limit_prices = [BigInt(1), (BigInt(MAX_PRICE) - BigInt(1))]
const limit_amounts = [-BigInt(MAX_AMOUNT), BigInt(MAX_AMOUNT)]
const limit_liquidities = [BigInt(MIN_LIQUIDITY), (BigInt(MAX_LIQUIDITY) - BigInt(1))]
const limit_longs = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]
const limit_shorts = [BigInt(0), ((BigInt(MAX_PRICE)-BigInt(1)) * (BigInt(MAX_AMOUNT)-BigInt(1)))]


const base_prices = random_inside_limit(limit_prices)

console.log(base_prices)

