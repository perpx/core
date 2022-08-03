%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.Position import settle, update, liquidate, get_position
from contracts.library.Position import Info

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
) -> (delta : felt):
    let (delta) = settle(address, price)
    return (delta)
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
) -> (delta : felt):
    let (delta) = liquidate(address, price, feeBps)
    return (delta)
end
