%lang starknet

from contracts.utils.access_control import only_owner, init_access_control, owner
from starkware.cairo.common.cairo_builtins import HashBuiltin

@storage_var
func storage_update() -> (value : felt):
end

@external
func only_owner_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    only_owner()
    storage_update.write(1)
    return ()
end

@external
func init_access_control_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt
) -> ():
    init_access_control(owner)
    return ()
end

@external
func get_owner_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    owner : felt
):
    let (_owner) = owner()
    return (owner=_owner)
end

@external
func get_update_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    update : felt
):
    let (_update) = storage_update.read()
    return (update=_update)
end
