function getOneBits(n: number) {
    var count = 0
    var mask = 1
    for (let i = 0; i < 32; i++) {
        if ((mask & n) != 0) {
            count++
        }
        mask <<= 1
    }
    return count
}

function generateNBitsWord(n: number, limit: number) {
    let bits: number[] = []
    let num = 0
    while (n > 0) {
        let bit = Math.floor(Math.random() * limit)
        if (!bits.includes(bit)) {
            n--
            bits.push(bit)
            num += 1 << bit
        }
    }
    return num
}

function decomposeBitWord(n: bigint) {
    let arr: bigint[] = []
    let mult = 1n
    while (n > 0n) {
        let r = n % 2n
        if (r == 1n) {
            arr.push(mult)
        }
        mult <<= 1n
        n >>= 1n
    }
    return arr
}

export { generateNBitsWord, getOneBits, decomposeBitWord }
