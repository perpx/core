import {
    getAccount,
    deployContract,
    updateContractAddress,
    getContractAddress,
    mintAndApprove,
    initializeExchangeContract,
    getRandomInt,
    saveLastOperation,
    getlastOperation,
    saveContractInformations,
    initContractInformations,
} from './utils/utils'
import { operation } from './utils/types'
import data from './data/data_cleaned.json'
import { Logger } from 'tslog'
import { Account } from 'starknet'

const log: Logger = new Logger()

let map = new Map<string, number>()
// maps from position id to user
// for 3000 operations, run 1000 users on starknet-devnet
let positions = new Map<bigint, string>()
let counter = 1

const pathErc20 = './starknet-artifacts/protostar/erc20.json'
const pathExchange = './starknet-artifacts/protostar/exchange.json'

const TS = 100_000
const SAVING = 10

main()

async function main() {
    const owner = await getAccount(0)
    map.set(owner.address, 0)
    await deploy(owner)
    await process_operations(owner)
}

async function deploy(owner: Account) {
    // deploy the contracts
    const erc20Args = {
        name: 370912461878743590817382610804631918n,
        symbol: 1431520323n,
        decimals: 6n,
        initial_supply_low: 100_000_000_000n,
        initial_supply_high: 0n,
        recipient: owner.address,
        owner: owner.address,
    }
    const erc20Address = await deployContract(pathErc20, erc20Args)
    updateContractAddress('erc20', erc20Address)
    log.info('Deployed erc20')

    const exchangeArgs = [
        owner.address,
        TS,
        erc20Address,
        10n,
        100n,
        // length of the array
        10n,
        // array
        20_000_000_000n,
        2_574_000_000n,
        1_000_000n,
        2_000_000n,
        3_000_000n,
        4_000_000n,
        5_000_000n,
        6_000_000n,
        7_000_000n,
        8_000_000n,
    ]
    const exchangeAddress = await deployContract(pathExchange, exchangeArgs)
    updateContractAddress('exchange', exchangeAddress)
    log.info(`Deployed exchange at ${exchangeAddress}`)

    await initializeExchangeContract(owner, exchangeAddress, erc20Address)
    log.info('Initialized exchange contract')
    initContractInformations()
    saveLastOperation(0)
}

async function process_operations(owner: Account) {
    // run the operations throught the contract
    let exchangeAddress = getContractAddress('exchange')
    let erc20Address = getContractAddress('erc20')

    let lastOperation = getlastOperation()
    let i = 0

    let block = data[0].block
    let price = 2_574_000_000
    let valid_until = 100
    let ts = TS

    for (let e of data.slice(lastOperation)) {
        let index: number
        let b = e.block
        if (b > block) {
            log.info('Executing trades')
            let prices = Array(10).fill(price)
            await owner.execute({
                entrypoint: 'update_prices',
                contractAddress: exchangeAddress,

                calldata: [10, ...prices, 1023, ts],
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
        log.info(`Applying operation ${e.type}`)
        switch (e.type) {
            case operation.OpenPosition: {
                price = parseInt(e.price!, 10)
                let factor = e.isLong ? 1n : -1n
                let amount = BigInt(e.amount!) * factor
                await mintAndApprove(
                    owner,
                    account,
                    erc20Address,
                    exchangeAddress,
                    e.margin!
                )
                await account.execute([
                    {
                        entrypoint: 'add_collateral',
                        contractAddress: exchangeAddress,
                        calldata: [e.margin!],
                    },
                    {
                        entrypoint: 'trade',
                        contractAddress: exchangeAddress,
                        calldata: [amount.toString(), 2, block + valid_until],
                    },
                ])
                positions.set(BigInt(e.positionId!), account.address)
                break
            }
            case operation.ClosePosition: {
                let account = await getAccount(index)
                await account.execute({
                    entrypoint: 'close',
                    contractAddress: exchangeAddress,
                    calldata: [2, block + valid_until],
                })
                price = parseInt(e.price!, 10)
                positions.delete(BigInt(e.positionId!))
                break
            }
            // TODO if liquidate does not pass (add try/catch), close the position
            case operation.Liquidate: {
                let user = positions.get(BigInt(e.positionId!)) ?? ''
                if (user) {
                    await account.execute({
                        entrypoint: 'liquidate',
                        contractAddress: exchangeAddress,
                        calldata: [user],
                    })
                    positions.delete(BigInt(e.positionId!))
                }
                break
            }
            case operation.AddCollateral: {
                let account = await getAccount(index)
                await mintAndApprove(
                    owner,
                    account,
                    erc20Address,
                    exchangeAddress,
                    e.amount!
                )
                await account.execute({
                    entrypoint: 'add_collateral',
                    contractAddress: exchangeAddress,
                    calldata: [e.amount!],
                })
                break
            }
            case operation.ProvideLiquidity: {
                let account = await getAccount(index)
                await mintAndApprove(
                    owner,
                    account,
                    erc20Address,
                    exchangeAddress,
                    e.amount!
                )
                await account.execute({
                    entrypoint: 'add_liquidity',
                    contractAddress: exchangeAddress,
                    calldata: [e.amount!, 2],
                })
                break
            }
        }
        if (i % SAVING == 0) {
            saveContractInformations(pathExchange, exchangeAddress)
        }
        i++
        saveLastOperation(lastOperation + i)
    }
}
