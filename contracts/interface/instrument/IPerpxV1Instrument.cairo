%lang starknet

from contracts.library.position import Info

# @title The interface for a perpx instrument
# @notice A perpx instrument keeps track of a pool's liquidity, longs and shorts

@contract_interface
namespace IPerpxV1Instrument:
    # @notice Returns the liquidity for the instrument
    # @param instrument The instrument's id
    # @return liquidity The liquidity for the instrument
    func get_liquidity(instrument : felt) -> (liquidity : felt):
    end

    # @notice Returns the owner's provided liquidity for the instrument
    # @param instrument The instrument's id
    # @param owner The owner
    # @return liquidity The liquidity provided by owner for the instrument
    func get_user_liquidity(owner : felt, instrument : felt) -> (liquidity : felt):
    end

    # @notice Returns the notional amount of longs for the instrument
    # @param instrument The instrument's id
    # @return amount The notional amount of longs for the instrument
    func get_longs(instrument : felt) -> (amount : felt):
    end
    # @notice Returns the notional amount of shorts for the instrument
    # @param instrument The instrument's id
    # @return amount The notional amount of shorts for the instrument
    func get_shorts(instrument : felt) -> (amount : felt):
    end
    ################################################################################
end
