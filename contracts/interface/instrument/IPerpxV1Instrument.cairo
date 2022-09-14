%lang starknet

from contracts.library.position import Info

// @title The interface for a perpx instrument
// @notice A perpx instrument keeps track of a pool's liquidity, longs and shorts

@contract_interface
namespace IPerpxV1Instrument {
    // @notice Returns the amount of longs for the instrument
    // @param instrument The instrument's id
    // @return amount The amount of longs for the instrument
    func longs(instrument: felt) -> (amount: felt) {
    }
    // @notice Returns the amount of shorts for the instrument
    // @param instrument The instrument's id
    // @return amount The amount of shorts for the instrument
    func shorts(instrument: felt) -> (amount: felt) {
    }
}
