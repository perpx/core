%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.Position import settle, update, liquidate, get_position
from contracts.library.Position import Info

@storage_var
func delta() -> (delta : felt):
end

@view
func view_delta{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    delt : felt
):
    let (delt) = delta.read()
    return (delt)
end

@external
func get_position_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (position : Info):
    let (pos) = get_position(address)
    return (pos)
end

@external
func settle_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt
) -> ():
    let (delt) = settle(address, price)
    delta.write(delt)
    return ()
end

@external
func update_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, amount : felt, feeBps : felt
) -> ():
    update(address, price, amount, feeBps)
    return ()
end

@external
func liquidate_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, feeBps : felt
) -> ():
    let (delt) = liquidate(address, price, feeBps)
    delta.write(delt)
    return ()
end
