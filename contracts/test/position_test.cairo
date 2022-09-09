%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.position import Position, Info

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
    owner : felt, instrument : felt
) -> (position : Info):
    let (_position) = Position.position(owner, instrument)
    return (position=_position)
end

@external
func update_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt, price : felt, amount : felt, fees : felt
) -> ():
    Position.update_position(owner, instrument, price, amount, fees)
    return ()
end

@external
func close_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt, price : felt, fees : felt
) -> ():
    let (delt) = Position.close_position(owner, instrument, price, fees)
    delta.write(delt)
    return ()
end
