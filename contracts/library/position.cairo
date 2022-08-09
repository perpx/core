%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, abs_value

from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_BOUND

# @title Position
# @notice Position represents an owner's position in an instrument

struct Info:
    member fees : felt
    member cost : felt
    member size : felt
end

@storage_var
func positions(address : felt) -> (position : Info):
end

# @notice View position
# @param address The address of the position's owner
# @return position The position
func view_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (position : Info):
    let (position) = positions.read(address)
    return (position)
end

# @notice Settle accumulated pnl and fees
# @return delta The collateral change
func settle{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt
) -> (delta : felt):
    let (info) = positions.read(address)
    # use tempvar to bypass <compound-expr> created if using let
    tempvar delta = price * info.size - info.cost - info.fees

    positions.write(address, Info(0, 0, 0))
    return (delta)
end

# @notice Update position size
# @param address The address of the position's owner
# @param price The price of the instrument
# @param amount The amount of the position update
# @param feeBps The fee in basic points
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, amount : felt, feeBps : felt
) -> ():
    alloc_locals
    let (info) = positions.read(address)

    let size = info.size + amount

    tempvar cost_inc = price * amount
    let cost = info.cost + cost_inc

    let (abs_val) = abs_value(cost_inc)
    let fees_inc = abs_val * feeBps
    let (fee_inc, _) = unsigned_div_rem(fees_inc, 10000)
    local fees = fee_inc + info.fees

    # check ranges for position state
    range_checks(amount, price, size, cost, fees)

    positions.write(address, Info(fees, cost, size))
    return ()
end

# @notice Liquidate a position
# @param price The liquidation price of position
# @param feeBps The fee bips to apply for liquidation
# @return delta The owner's collateral change
func liquidate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, feeBps : felt
) -> (delta : felt):
    let (info) = positions.read(address)

    tempvar cost_inc = (-info.size) * price
    let cost = info.cost + cost_inc

    let (abs_val) = abs_value(cost_inc)
    let fees_inc = abs_val * feeBps
    let (fee_inc, _) = unsigned_div_rem(fees_inc, 10000)
    tempvar fees = fee_inc + info.fees

    positions.write(address, Info(fees, cost, 0))
    let (delta) = settle(address, price)

    return (delta)
end

# @notice Performs range checks on the position state
# @param amount The amount traded
# @param size The size of the position after trade
# @param cost The cost of the position after trade
# @param fees The fees of the position after trade
func range_checks{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, price : felt, size : felt, cost : felt, fees : felt
) -> ():
    # check amount is within bounds
    assert [range_check_ptr] = amount + MAX_AMOUNT
    assert [range_check_ptr + 1] = MAX_AMOUNT - amount - 1

    # check price is within bounds
    [range_check_ptr + 2] = price
    assert [range_check_ptr + 3] = MAX_PRICE - price - 1

    # check size is within bounds
    assert [range_check_ptr + 4] = size + MAX_AMOUNT
    assert [range_check_ptr + 5] = MAX_AMOUNT - size - 1

    let range_check_ptr = range_check_ptr + 6
    return ()
end
