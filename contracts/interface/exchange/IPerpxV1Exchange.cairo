%lang starknet

from contracts.library.position import Info

# @title The interface for a perpx exchange
# @notice A perpx exchange facilitates longing and shorting any data feed
# @dev Contract broken down in 4 levels:
# @dev Permissionless contract methods
# @dev Mutable contract state
# @dev Owner methods

@contract_interface
namespace IPerpxV1Exchange:
    #
    # PERMISSIONLESS
    #

    # @notice Trade an amount of the index
    # @param amount The amount to trade
    # @param instrument The instrument to trade
    func trade(amount : felt, instrument : felt) -> ():
    end
    # @notice Close the position of the owner, set fees and pnl to zero
    # @param instrument The instrument for which to close the position
    func close(instrument : felt) -> ():
    end
    # @notice Liquidate all positions of owner
    # @param owner The owner of the positions
    func liquidate(owner : felt) -> ():
    end

    # @notice Add liquidity for the instrument
    # @param amount The change in liquidity
    # @param instrument The instrument to add liquidity for
    func add_liquidity(amount : felt, instrument : felt) -> ():
    end
    # @notice Remove liquidity for the instrument
    # @param amount The change in liquidity
    # @param instrument The instrument to remove liquidity for
    func remove_liquidity(amount : felt, instrument : felt) -> ():
    end
    # @notice Add collateral for the owner
    # @param amount The change in collateral
    func add_collateral(amount : felt) -> ():
    end
    # @notice Remove collateral
    # @param amount The change in collateral
    func remove_collateral(amount : felt) -> ():
    end

    #
    # MUTABLE
    #

    # @notice Returns instruments for which user has a position
    # @param owner The owner of the positions
    # @return instruments The owner's instruments
    func get_user_instruments(owner : felt) -> (instruments : felt):
    end
    # @notice Returns the price of the instrument
    # @param instrument The instrument
    # @return price The oracle's price for the instrument
    func get_price(instrument : felt) -> (price : felt):
    end
    # @notice Returns the amount of collateral for the instrument
    # @param owner The owner of the collateral
    # @param instrument The collateral's instrument
    # @return collateral The amount of collateral for the instrument
    func get_collateral(owner : felt, instrument : felt) -> (collateral : felt):
    end
    # @notice Returns the number of instruments
    # @return count The number of instruments on the exchange
    func get_instrument_count() -> (count : felt):
    end

    #
    # OWNER
    #

    # @notice Update the prices of the instruments
    # @param prices_len The number of instruments to update
    # @param prices The prices of the instruments to update
    # @param instruments The instruments to update
    func update_prices(prices_len : felt, prices : felt*, instruments : felt) -> ():
    end
end
