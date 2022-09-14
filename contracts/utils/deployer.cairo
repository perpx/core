%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.memcpy import memcpy
from starkware.starknet.common.syscalls import deploy, get_caller_address
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.bool import FALSE

//
// Events
//

@event
func contract_deployed(contract_address: felt) {
}

//
// Storage
//

@storage_var
func salt() -> (value: felt) {
}

@external
func deploy_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    args_len: felt, args: felt*, class_hash: felt, has_owner: felt
) -> () {
    alloc_locals;
    let (current_salt) = salt.read();
    if (has_owner == 1) {
        let (owner) = get_caller_address();
        let (local arr) = alloc();
        assert [arr] = owner;
        memcpy(arr + 1, args, args_len);
        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=args_len + 1,
            constructor_calldata=arr,
            deploy_from_zero=FALSE,
        );
    } else {
        let (contract_address) = deploy(
            class_hash=class_hash,
            contract_address_salt=current_salt,
            constructor_calldata_size=args_len,
            constructor_calldata=args,
            deploy_from_zero=FALSE,
        );
    }
    salt.write(value=current_salt + 1);
    contract_deployed.emit(contract_address=contract_address);
    return ();
}
