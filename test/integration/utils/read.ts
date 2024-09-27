import fs from 'fs'
import { Account, Contract, json } from 'starknet'
import { getProvider } from './utils'

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
