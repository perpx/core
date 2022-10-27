import fs from 'fs'
import { config } from 'dotenv'
import { Provider, ProviderOptions, Account, ec } from 'starknet'
import { json, Contract } from 'starknet'
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
    ])
    const resp = await owner.execute({
        entrypoint: 'approve',
        contractAddress: erc20Address,
        calldata: [exchangeAddress, 200_000_000_000, 0],
    })
    console.log(resp)
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
