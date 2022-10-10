%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

//
// Events
//

@event
func Trade(owner: felt, instrument: felt, price: felt, amount: felt, fee: felt) {
}

@event
func Close(owner: felt, instrument: felt, price: felt, fee: felt, delta: felt) {
}

@event
func Liquidate(owner: felt, instruments: felt) {
}

@event
func UpdateCollateral(owner: felt, amount: felt) {
}

@event
func UpdateLiquidity(owner: felt, amount: felt) {
}
