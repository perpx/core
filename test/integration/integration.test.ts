import {
    getAccount,
    deployContract,
    callContract,
    getContract,
    getRandomInt,
} from './utils/utils'
import { Operation, operation } from './utils/types'
import data from './data/data_cleaned.json'
import { Logger } from 'tslog'

const log: Logger = new Logger()

let map = new Map<string, number>()
// maps from position id to user
let positions = new Map<bigint, string>()
let counter = 1

const pathErc20 = './starknet-artifacts/protostar/erc20.json'
const pathExchange = './starknet-artifacts/protostar/exchange.json'

async function main() {
    // deploy the contracts
    const owner = await getAccount(0)
    map.set(owner.address, 0)
    const erc20Args = {
        name: '370912461878743590817382610804631918',
        symbol: '1431520323',
        decimals: '6',
        initial_supply_low: '10',
        initial_supply_high: '0',
        recipient: owner.address,
        owner: owner.address,
    }
    const erc20Address = await deployContract(pathErc20, erc20Args)
    log.info('Deployed erc20')
    const exchangeArgs = [
        owner.address,
        erc20Address,
        '10',
        '100',
        // length of the array
        '10',
        // array
        '20000',
        '2574',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
    ]
    const exchangeAddress = await deployContract(pathExchange, exchangeArgs)
    log.info(`Deployed exchange at ${exchangeAddress}`)
    await owner.execute({
        entrypoint: 'set_last_update_price_delta',
        contractAddress: exchangeAddress,
        calldata: ['2'],
    })
    log.info('Set last update price delta')

    // run the operations throught the contract
    let block = data[0].block
    let price = 2_574
    let valid_until = 100
    let ts = 100_000

    for (let e of data) {
        let index: number
        let b = e.block
        if (b > block) {
            await owner.execute({
                entrypoint: 'update_prices',
                contractAddress: exchangeAddress,

                calldata: ['1', price, '2', ts],
            })
            block = b
            ts += getRandomInt(4)
        }
        let user = e.type == operation.Liquidate ? owner.address : e.user!
        if (map.has(user)) {
            index = map.get(user)!
        } else {
            index = counter
            map.set(user, index)
            counter++
        }
        let account = await getAccount(index)
        switch (e.type) {
            case operation.OpenPosition: {
                price = parseInt(e.price!, 10)
                let factor = e.isLong ? 1n : -1n
                let amount = BigInt(e.amount!) * factor
                account.execute({
                    entrypoint: 'trade',
                    contractAddress: exchangeAddress,
                    calldata: [amount.toString(), 1, block + valid_until],
                })
                positions.set(BigInt(e.positionId!), account.address)
            }
            case operation.ClosePosition: {
                let account = await getAccount(index)
                account.execute({
                    entrypoint: 'close',
                    contractAddress: exchangeAddress,
                    calldata: [1, block + valid_until],
                })
                price = parseInt(e.price!, 10)
                positions.delete(BigInt(e.positionId!))
            }
            case operation.Liquidate: {
                let user = positions.get(BigInt(e.positionId!)) ?? '0'
                account.execute({
                    entrypoint: 'liquidate',
                    contractAddress: exchangeAddress,
                    calldata: [user],
                })
                positions.delete(BigInt(e.positionId!))
            }
            case operation.AddCollateral: {
                let account = await getAccount(index)
                account.execute({
                    entrypoint: 'add_collateral',
                    contractAddress: exchangeAddress,
                    calldata: [e.amount!],
                })
            }
        }
    }
}

main()
