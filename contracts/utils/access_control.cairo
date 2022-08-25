%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from starkware.starknet.common.syscalls import get_caller_address

#
# Events
#
@event
func access_control_initialized(owner : felt):
end

#
# Storage
#

@storage_var
func storage_owner() -> (owner : felt):
end

#
# Modifiers
#

# @notice Modifier for only owner callables
func only_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    let (caller) = get_caller_address()
    let (_owner) = storage_owner.read()

    with_attr error_message("callable limited to owner"):
        assert caller = _owner
    end
    return ()
end

#
# Functions
#

# @notice Initialize the contract owner
# @param owner The contract owner
# @param exchange The exchange contract
func init_access_control{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt
) -> ():
    with_attr error_message("owner cannot be the zero address"):
        assert_not_zero(owner)
    end

    storage_owner.write(owner)

    access_control_initialized.emit(owner)
    return ()
end

# @notice View the contract owner
# @return owner The contract owner
func owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (owner : felt):
    let (_owner) = storage_owner.read()
    return (owner=_owner)
end
