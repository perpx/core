%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import deploy
from starkware.cairo.common.bool import FALSE

#
# Events
#

@event
func contract_deployed(contract_address : felt):
end

#
# Storage
#

@storage_var
func salt() -> (value : felt):
end

@external
func deploy_contract{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    args_len : felt, args : felt*, class_hash : felt
) -> ():
    let (current_salt) = salt.read()
    let (contract_address) = deploy(
        class_hash=class_hash,
        contract_address_salt=current_salt,
        constructor_calldata_size=args_len,
        constructor_calldata=args,
        deploy_from_zero=FALSE,
    )
    salt.write(value=current_salt + 1)
    contract_deployed.emit(contract_address=contract_address)
    return ()
end
