%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import signed_div_rem, abs_value

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
func storage_positions(owner : felt, instrument : felt) -> (position : Info):
end

namespace Position:
    #
    # Functions
    #

    # @notice Get position
    # @param owner The address of the position's owner
    # @param instrument The instrument for the position
    # @return position The position
    func position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, instrument : felt
    ) -> (position : Info):
        let (_position) = storage_positions.read(owner, instrument)
        return (position=_position)
    end

    # @notice Update position size
    # @param owner The address of the position's owner
    # @param instrument The instrument for the position
    # @param price The price of the instrument
    # @param amount The amount of the position update
    # @param fees The fees for the update
    func update_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, instrument : felt, price : felt, amount : felt, fees : felt
    ) -> ():
        alloc_locals
        let (info) = storage_positions.read(owner, instrument)

        let size = info.size + amount
        let new_fees = fees + info.fees

        tempvar cost_inc = price * amount
        let cost = info.cost + cost_inc

        storage_positions.write(owner, instrument, Info(new_fees, cost, size))
        return ()
    end

    # @notice Close a position
    # @param owner The address of the position's owner
    # @param instrument The instrument for the position
    # @param price The closing price of the position
    # @param fees The fees for closing
    # @return delta The owner's collateral change
    func close_position{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, instrument : felt, price : felt, fees : felt
    ) -> (delta : felt):
        let (info) = storage_positions.read(owner, instrument)

        tempvar cost_inc = price * (-info.size)
        let cost = info.cost + cost_inc

        tempvar delta = (-cost) - fees - info.fees
        storage_positions.write(owner, instrument, Info(0, 0, 0))

        return (delta)
    end
end
