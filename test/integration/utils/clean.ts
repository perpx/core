import fs from 'fs'
import { Operation, operation } from '../utils/types'
import untypedData from '../data/data.json'
import clean_data from '../data/data_cleaned.json'

const LIMIT = 3000

let openPositions = new Map<bigint, boolean>()
const data: any[] = untypedData

clean()

function clean() {
    let myData: Operation[] = []
    for (const event of data) {
        let block = BigInt(event['block-number'])
        if (
            event['open-position'] !== null &&
            event['open-position']['product-id'] == 2
        ) {
            console.log('ADDED OPEN')
            let oracle_price = BigInt(event['open-position']['oracle-price'])
            let margin = BigInt(event['open-position']['margin'])
            let price = BigInt(event['open-position']['price'])
            let leverage = BigInt(event['open-position']['leverage'])
            let notional = margin * leverage // (precision 16)
            let amount = notional / price / BigInt(100) // (precision 6)
            const positionId = BigInt(event['open-position']['position-id'])
            myData.push({
                user: event['open-position'].user,
                positionId: positionId,
                amount: amount,
                margin: margin / BigInt(100),
                price: oracle_price / BigInt(100),
                isLong: true,
                block: block,
                type: operation.OpenPosition,
            })
            openPositions.set(positionId, true)
        }
        if (
            event['close-position'] !== null &&
            openPositions.has(BigInt(event['close-position']['position-id']))
        ) {
            console.log('ADDED CLOSE')
            let price = BigInt(event['close-position']['price'])
            myData.push({
                user: event['close-position'].user,
                positionId: BigInt(event['close-position']['position-id']),
                price: price / BigInt(100),
                block: block,
                type: operation.ClosePosition,
            })
        }
        if (event['staked'] !== null) {
            myData.push({
                user: event['staked'].user,
                amount: BigInt(event['staked'].amount) / 100n,
                block: block,
                type: operation.ProvideLiquidity,
            })
        }
        if (event['redeemed'] !== null) {
            myData.push({
                user: event['redeemed'].user,
                amount: BigInt(event['redeemed'].amount) / 100n,
                block: block,
                type: operation.RemoveLiquidity,
            })
        }
        if (event['add-margin'] !== null) {
            myData.push({
                user: event['add-margin'].user,
                amount: BigInt(event['add-margin'].margin) / 100n,
                block: block,
                type: operation.AddCollateral,
            })
        }
        if (
            event['position-liquidated'] !== null &&
            openPositions.has(event['position-liquidated']['position-id'])
        ) {
            myData.push({
                positionId: BigInt(event['position-liquidated']['position-id']),
                block: block,
                type: operation.Liquidate,
            })
        }
        if (myData.length == 3000) break
    }
    const jsonData = JSON.stringify(myData, (_, value) => {
        return typeof value === 'bigint' ? value.toString() : value
    })
    fs.writeFile(
        './test/integration/data/data_cleaned.json',
        jsonData,
        function (err) {
            if (err) {
                console.log(err)
            }
        }
    )
}

function checkUsers() {
    let map = new Map<string, boolean>()
    for (let i = 0; i < LIMIT; i++) {
        switch (clean_data[i].type) {
            case operation.OpenPosition: {
                map.has(clean_data[i].user!)
                    ? 0
                    : map.set(clean_data[i].user!, true)
                break
            }
            case operation.AddCollateral: {
                map.has(clean_data[i].user!)
                    ? 0
                    : map.set(clean_data[i].user!, true)
                break
            }
            case operation.ProvideLiquidity: {
                map.has(clean_data[i].user!)
                    ? 0
                    : map.set(clean_data[i].user!, true)
                break
            }
        }
    }
    console.log('MAP SIZE', map.size)
}

function copy() {
    let testData = []
    for (let i = 0; i < 50; i++) {
        testData.push(data[i])
    }
    const jsonData = JSON.stringify(testData)
    fs.writeFile(
        './test/integration/data/data_test.json',
        jsonData,
        function (err) {
            if (err) {
                console.log(err)
            }
        }
    )
}
