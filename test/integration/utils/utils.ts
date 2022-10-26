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
        const provider = new Provider(options)

        return provider
    }
}

export async function getAccount(index: number) {
    const response = await fetch('http://127.0.0.1:5050/predeployed_accounts', {
        method: 'GET',
    })
    const res = await response.json()
    const provider = getProvider()!
    const starkKeyPair = ec.getKeyPair(res[index].private_key)
    const account = new Account(provider, res[index].address, starkKeyPair)
    return account
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

export async function callContract(
    path: string,
    address: string,
    entrypoint: string,
    calldata: any[]
) {
    const provider = getProvider()
    const compiled = json.parse(fs.readFileSync(path).toString('ascii'))

    const contract = new Contract(compiled.abi, address, provider)

    return await contract.call(entrypoint, calldata)
}

///
/// MATH
///

export function getRandomInt(max: number) {
    return Math.floor(Math.random() * max)
}
