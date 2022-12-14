%lang starknet

from contracts.utils.access_control import assert_only_owner, init_access_control, owner
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func storage_update() -> (value: felt) {
}

@external
func assert_only_owner_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    ) {
    assert_only_owner();
    storage_update.write(1);
    return ();
}

@external
func init_access_control_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt
) -> () {
    init_access_control(owner);
    return ();
}

@external
func get_owner_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    owner: felt
) {
    let (_owner) = owner();
    return (owner=_owner);
}

@external
func get_update_test{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    update: felt
) {
    let (_update) = storage_update.read();
    return (update=_update);
}
