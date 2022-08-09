%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.Position import (
    settle_position,
    update_position,
    liquidate_position,
    position,
)
from contracts.library.Position import Info

@storage_var
func delta() -> (delta : felt):
end

@view
func get_delta_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    delt : felt
):
    let (delt) = delta.read()
    return (delt)
end

@external
func get_position_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (position : Info):
    let (_position) = position(address)
    return (position=_position)
end

@external
func settle_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt
) -> ():
    let (delt) = settle_position(address, price)
    delta.write(delt)
    return ()
end

@external
func update_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, amount : felt, feeBps : felt
) -> ():
    update_position(address, price, amount, feeBps)
    return ()
end

@external
func liquidate_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, feeBps : felt
) -> ():
    let (delt) = liquidate_position(address, price, feeBps)
    delta.write(delt)
    return ()
end
