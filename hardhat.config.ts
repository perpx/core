import { HardhatUserConfig } from 'hardhat/types'
import '@shardlabs/starknet-hardhat-plugin'
module.exports = {
    solidity: '0.8.9',
    starknet: {
        network: 'main',
    },
    networks: {
        main: {
            url: 'http://127.0.0.1:5050',
        },
    },
    mocha: {
        timeout: 100000,
    },
}
