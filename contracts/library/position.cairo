%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import signed_div_rem, abs_value

from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_BOUND

# @title Position
# @notice Position represents an owner's position in an instrument

#
# Structure
#

struct Info:
    member fees : felt
    member cost : felt
    member size : felt
end

#
# Storage
#

@storage_var
func storage_positions(address : felt) -> (position : Info):
end

#
# Functions
#

# @notice Get position
# @param address The address of the position's owner
# @return position The position
func position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt
) -> (position : Info):
    let (_position) = storage_positions.read(address)
    return (position=_position)
end

# @notice Update position size
# @param address The address of the position's owner
# @param price The price of the instrument
# @param amount The amount of the position update
# @param fee_bps The fee in basic points
func update_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, amount : felt, fee_bps : felt
) -> ():
    alloc_locals
    let (info) = storage_positions.read(address)

    let size = info.size + amount

    tempvar cost_inc = price * amount
    let cost = info.cost + cost_inc

    let (abs_val) = abs_value(cost_inc)
    let fees_inc = abs_val * fee_bps
    let (fee_inc, _) = signed_div_rem(fees_inc, 1000000, MAX_BOUND)
    local fees = fee_inc + info.fees

    # check ranges for position state
    range_checks(amount, price, size)

    storage_positions.write(address, Info(fees, cost, size))
    return ()
end

# @notice Close a position
# @param price The closing price of the position
# @param fee_bps The fee bips to apply for closing
# @return delta The owner's collateral change
func close_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, fee_bps : felt
) -> (delta : felt):
    let (info) = storage_positions.read(address)

    tempvar cost_inc = price * (-info.size)
    let cost = info.cost + cost_inc

    let (abs_val) = abs_value(cost_inc)
    let fees_inc = abs_val * fee_bps
    let (fee_inc, _) = signed_div_rem(fees_inc, 1000000, MAX_BOUND)
    let fees = fee_inc + info.fees

    tempvar delta = (-cost) - fees
    storage_positions.write(address, Info(0, 0, 0))

    return (delta)
end

# @notice Performs range checks on the position state
# @param amount The amount traded
# @param size The size of the position after trade
# @param cost The cost of the position after trade
# @param fees The fees of the position after trade
func range_checks{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, price : felt, size : felt
) -> ():
    # check amount is within bounds
    assert [range_check_ptr] = amount + MAX_AMOUNT - 1
    assert [range_check_ptr + 1] = MAX_AMOUNT - amount - 1

    # check price is within bounds
    [range_check_ptr + 2] = price
    assert [range_check_ptr + 3] = MAX_PRICE - price - 1

    # check size is within bounds
    assert [range_check_ptr + 4] = size + MAX_AMOUNT - 1
    assert [range_check_ptr + 5] = MAX_AMOUNT - size - 1

    let range_check_ptr = range_check_ptr + 6
    return ()
end
