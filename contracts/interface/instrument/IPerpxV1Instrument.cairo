%lang starknet

from starkware.cairo.common.uint256 import Uint256
# @title The interface for a perpx instrument
# @notice A perpx instrument facilitates longing and shorting any data feed
# @dev Contract broken down in 4 levels:
# @dev Permissionless contract methods
# @dev Immutable contract state
# @dev Mutable contract state
# @dev Owner methods

@contract_interface
namespace IPerpxV1Instrument:
    # PERMISSIONLESS

    # @notice Trade an amount of the index
    # @param amount The amount to trade of
    func trade(amount : Uint256) -> ():
    end
    # @notice Liquidate the instrument position from the owner
    # @param owner The owner of the position
    func liquidate(owner : felt) -> ():
    end
    ################################################################################

    # IMMUTABLE

    # @notice The exchange contract
    # @return address The exchange contract address
    func exchange() -> (address : felt):
    end
    # @notice The collateral token
    # @return address The collateral token address
    func collateral_token() -> (address : felt):
    end
    ################################################################################

    # MUTABLE

    # @notice Returns the information about a position by the position's owner
    # @param owner The position's key is the owner
    # @return fees The amount of fees paid by the owner,
    # cost The current cost of the open position
    # size The current size of the open position
    func positions(address : felt) -> (fees : felt, cost : felt, size : felt):
    end
    # @notice Returns the imbalance of the pool
    # @return The imbalance of the pool
    func imbalance() -> (imbalance : felt):
    end
    # @notice Returns the amount of open interests in the pool
    # @return open_interests The amount of open interests in the pool
    func open_interests() -> (open_interests : Uint256):
    end
    # @notice Returns the price of the instrument
    # @return price The price of the instrument
    func price() -> (price : felt):
    end
    # @notice Returns the fee of the instrument
    # @return fee The fee of the instrument
    func fee() -> (fee : felt):
    end

    # OWNER

    # @notice Set the value of the instrument
    # @param value The value of the instrument
    func update_value(value : Uint256) -> ():
    end
    # @notice Settle the position of the owner, set fees and pnl to zero
    # @param owner The owner of the position
    # @return delta The change in the user collateral
    func settle_position(address : felt) -> (delta : felt):
    end
    ################################################################################
end
