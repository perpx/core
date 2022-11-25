import fs from 'fs'
import { config } from 'dotenv'
import { Provider, ProviderOptions, Account, ec } from 'starknet'
import { json, Contract } from 'starknet'
import { callContract } from '../utils/read'
config()

export function getProvider() {
    // address of starknet-dev
    const url = process.env.PROVIDER_URL
    if (url !== undefined) {
        const options: ProviderOptions = { sequencer: { baseUrl: url } }
        return new Provider(options)
    }
}

export async function getAccount(index: number) {
    const response = await fetch('http://127.0.0.1:5050/predeployed_accounts', {
        method: 'GET',
    })
    const res = await response.json()
    const provider = getProvider()!
    const starkKeyPair = ec.getKeyPair(res[index].private_key)
    return new Account(provider, res[index].address, starkKeyPair)
}

export async function getContract(path: string, address: string) {
    const provider = getProvider()
    const compiled = json.parse(fs.readFileSync(path).toString('ascii'))

    return new Contract(compiled.abi, address, provider)
}

export async function deployContract(
    compiledPath: string,
    calldata: {},
    account?: Account
) {
    let deployer
    if (account !== undefined) {
        deployer = account
    } else {
        deployer = getProvider()
    }
    const compiled = json.parse(fs.readFileSync(compiledPath).toString('ascii'))
    const response = await deployer!.deployContract({
        contract: compiled,
        constructorCalldata: Object.values(calldata),
    })

    await deployer!.waitForTransaction(response.transaction_hash)
    return response.contract_address
}

///
/// EXCHANGE
///

export async function initializeExchangeContract(
    owner: Account,
    exchangeAddress: string,
    erc20Address: string
) {
    const FRACT_PART = BigInt(2 ** 61)
    let k = BigInt(42) * FRACT_PART // parameter for eth
    let tau = BigInt(36000) * FRACT_PART // half life of 10 hours
    let params = Array(10).fill([k.toString(), tau.toString()]).flat()
    await owner.execute([
        {
            entrypoint: 'set_last_update_price_delta',
            contractAddress: exchangeAddress,
            calldata: [2],
        },
        {
            entrypoint: 'set_fee_rate',
            contractAddress: exchangeAddress,
            calldata: [100],
        },
        {
            entrypoint: 'update_margin_parameters',
            contractAddress: exchangeAddress,
            calldata: [10, ...params, 1023],
        },
    ])
    await owner.execute({
        entrypoint: 'approve',
        contractAddress: erc20Address,
        calldata: [exchangeAddress, 200_000_000_000, 0],
    })
}

export function initContractInformations() {
    fs.writeFileSync('./test/integration/data/output.json', JSON.stringify([]))
}

export async function saveContractInformations(path: string, address: string) {
    let output = JSON.parse(
        fs.readFileSync('./test/integration/data/output.json').toString('ascii')
    )
    let results = {
        operations_count: 0,
        price: 0,
        open_interests: {},
        liquidity: 0,
    }
    results['operations_count'] = (
        await callContract(path, address, 'view_operations_count', [])
    )[0].toString()
    results['price'] = (await callContract(path, address, 'view_price', [2]))[0].toString()
    let open_interests = await callContract(
        path,
        address,
        'view_open_interests',
        [2]
    )
    results['open_interests'] = {
        longs: open_interests[0].toString(),
        shorts: open_interests[1].toString(),
    }
    results['liquidity'] = (
        await callContract(path, address, 'view_liquidity', [2])
    )[0].toString()
    output.push(results)
    fs.writeFileSync(
        './test/integration/data/output.json',
        JSON.stringify(output)
    )
}

///
/// ERC20
///
export async function mintAndApprove(
    owner: Account,
    account: Account,
    erc20Address: string,
    exchangeAddress: string,
    amount: string
) {
    await owner.execute({
        entrypoint: 'mint',
        contractAddress: erc20Address,
        calldata: [account.address, amount, '0'],
    })
    await account.execute({
        entrypoint: 'approve',
        contractAddress: erc20Address,
        calldata: [exchangeAddress, amount, '0'],
    })
}

///
/// CONTRACTS STORAGE
///

export function updateContractAddress(name: string, address: string) {
    let addresses
    try {
        addresses = fs
            .readFileSync('./test/integration/data/addresses.json')
            .toString('ascii')
        if (!addresses) {
            addresses = {}
        } else {
            addresses = JSON.parse(addresses)
        }
    } catch (e) {
        addresses = {}
    }
    const newAddresses = { ...addresses, [name]: address }
    fs.writeFileSync(
        './test/integration/data/addresses.json',
        JSON.stringify(newAddresses)
    )
}

export function getContractAddress(name: string) {
    const addresses = JSON.parse(
        fs
            .readFileSync('./test/integration/data/addresses.json')
            .toString('ascii')
    )
    return addresses[name]
}

export function saveLastOperation(index: number) {
    const newOperation = { index: index }
    fs.writeFileSync(
        './test/integration/data/operation.json',
        JSON.stringify(newOperation)
    )
}

export function getlastOperation() {
    const operation = JSON.parse(
        fs
            .readFileSync('./test/integration/data/operation.json')
            .toString('ascii')
    )
    return operation['index']
}

///
/// MATH
///

export function getRandomInt(max: number) {
    return Math.floor(Math.random() * max)
}
