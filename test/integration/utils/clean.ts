import fs from 'fs'
import { Operation, operation } from '../utils/types'
import data from '../data/data.json'

const LIMIT = 3000

clean()

function clean() {
    let myData: Operation[] = []
    for (let i = 0; i < LIMIT; i++) {
        let block = BigInt(data[i]['block-number'])
        console.log(`At iteration ${i}`)
        if (data[i]['open-position'] !== null) {
            let oracle_price = BigInt(
                data[i]['open-position']!['oracle-price']!
            )
            let margin = BigInt(data[i]['open-position']!['margin']!)
            let price = BigInt(data[i]['open-position']!['price']!)
            let leverage = BigInt(data[i]['open-position']!['leverage']!)
            let notional = margin * leverage // (precision 16)
            let amount = notional / price / BigInt(100) // (precision 6)
            myData.push({
                user: data[i]['open-position']!.user,
                positionId: BigInt(data[i]['open-position']!['position-id']!),
                amount: amount,
                price: price / BigInt(100),
                isLong: true,
                block: block,
                type: operation.OpenPosition,
            })
        }
        if (data[i]['close-position'] !== null) {
            let price = BigInt(data[i]['close-position']!['price']!)
            myData.push({
                user: data[i]['close-position']!.user,
                price: price / BigInt(100),
                block: block,
                type: operation.ClosePosition,
            })
        }
        if (data[i]['staked'] !== null) {
            myData.push({
                user: data[i]['staked']!.user,
                amount: BigInt(data[i]['staked']!.amount) / 100n,
                block: block,
                type: operation.ProvideLiquidity,
            })
        }
        if (data[i]['redeemed'] !== null) {
            myData.push({
                user: data[i]['redeemed']!.user,
                amount: BigInt(data[i]['redeemed']!.amount) / 100n,
                block: block,
                type: operation.RemoveLiquidity,
            })
        }
        if (data[i]['add-margin'] !== null) {
            myData.push({
                user: data[i]['add-margin']!.user,
                amount: BigInt(data[i]['add-margin']!.margin) / 100n,
                block: block,
                type: operation.AddCollateral,
            })
        }
        if (data[i]['position-liquidated'] !== null) {
            myData.push({
                positionId: BigInt(
                    data[i]['position-liquidated']!['position-id']!
                ),
                block: block,
                type: operation.Liquidate,
            })
        }
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

clean()

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
