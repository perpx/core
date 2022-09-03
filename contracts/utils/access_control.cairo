%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_not_zero
from openzeppelin.access.ownable.library import Ownable

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

    Ownable.initializer(owner)

    return ()
end

# @notice Checks contract owner is caller
func assert_only_owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> ():
    Ownable.assert_only_owner()
    return ()
end

# @notice Transfers contract ownership
# @param new_owner The new contract owner
func transfer_ownership{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    new_owner : felt
) -> ():
    Ownable.transfer_ownership(new_owner=new_owner)
    return ()
end

# @notice View the contract owner
# @return owner The contract owner
func owner{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (owner : felt):
    let (_owner) = Ownable.owner()
    return (owner=_owner)
end
