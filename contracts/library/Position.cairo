%lang starknet

from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt_felt

from contracts.constants.perpx_constants import MAX_SIZE
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

# @notice Get position
# @return position The position
func get_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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
    # TODO check size < max(felt)/max(price) = max(size) during trade
    tempvar delta = price * info.size - info.cost - info.fees  # use tempvar to bypass <compound-expr> created if using let

    positions.write(address, Info(0, 0, 0))
    return (delta)
end

# @notice Update position size
func update{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, price : felt, amount : felt, feeBps : felt
) -> ():
    let (info) = positions.read(address)

    with_attr error_message("total position size limited to {MAX_SIZE}."):
        assert_lt_felt(amount, MAX_SIZE - info.size)
    end

    let size = info.size + amount

    tempvar cost_inc = price * amount + info.cost
    let cost = info.cost + cost_inc

    # TODO take abs of cost_inc and signed_div_rem
    # Problem: when performing a abs value, fees_inc must be [0, rc_bound)
    # Problem: when performing a signed_div_rem, the quotient will be in [0, bound) (bound limited to rc_bound)
    tempvar fees = cost_inc * feeBps + info.fees

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

    tempvar fees = cost_inc * feeBps + info.fees

    positions.write(address, Info(fees, cost, 0))
    let (delta) = settle(address, price)

    return (delta)
end
