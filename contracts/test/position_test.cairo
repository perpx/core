%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.Position import update_position, close_position, position
from contracts.library.Position import Info

@storage_var
func delta() -> (delta: felt) {
}

@view
func get_delta_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    delt: felt
) {
    let (delt) = delta.read();
    return (delt,);
}

@external
func get_position_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt
) -> (position: Info) {
    let (_position) = position(address);
    return (position=_position);
}

@external
func update_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt, price: felt, amount: felt, fee_bps: felt
) -> () {
    update_position(address, price, amount, fee_bps);
    return ();
}

@external
func close_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    address: felt, price: felt, fee_bps: felt
) -> () {
    let (delt) = close_position(address, price, fee_bps);
    delta.write(delt);
    return ();
}
