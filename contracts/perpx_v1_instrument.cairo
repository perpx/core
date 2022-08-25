%lang starknet

from contracts.library.position import Info, position, update_position, close_position
from contracts.utils.access_control import init_access_control, only_owner

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address

#
# Storage
#

@storage_var
func storage_liquidity(instrument : felt) -> (liquidity : felt):
end

@storage_var
func storage_user_liquidity(owner : felt, instrument : felt) -> (liquidity : felt):
end

@storage_var
func storage_longs(instrument : felt) -> (amount : felt):
end

@storage_var
func storage_shorts(instrument : felt) -> (amount : felt):
end

#
# Functions
#

# @notice Returns the liquidity for the instrument
# @param instrument The instrument's id
# @return liquidity The liquidity for the instrument
func get_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (liquidity : felt):
    let (liquidity) = storage_liquidity.read(instrument)
    return (liquidity=liquidity)
end

# @notice Returns the owner's provided liquidity for the instrument
# @param instrument The instrument's id
# @param owner The owner
# @return liquidity The liquidity provided by owner for the instrument
func get_user_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt
) -> (liquidity : felt):
    let (liquidity) = storage_user_liquidity.read(owner, instrument)
    return (liquidity=liquidity)
end

# @notice Returns the notional amount of longs for the instrument
# @param instrument The instrument's id
# @return amount The notional amount of longs for the instrument
func get_longs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (amount : felt):
    let (amount) = storage_longs.read(instrument)
    return (amount=amount)
end

# @notice Returns the notional amount of shorts for the instrument
# @param instrument The instrument's id
# @return amount The notional amount of shorts for the instrument
func get_shorts{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (amount : felt):
    let (amount) = storage_shorts.read(instrument)
    return (amount=amount)
end

# @notice Update long or short notional amount
# @dev Internal functions
# @param owner The liquidity provider
# @param instrument The instrument's id
# @param price The price of the instrument
# @amount The amount of liquidity
func update_long_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt, price : felt, amount : felt
) -> ():
    # TODO update the position of the owner
    # TODO update the short or long instrument state value
    return ()
end

# @notice Update the pool's liquidity
# @dev Internal functions
# @param owner The liquidity provider
# @param instrument The instrument's id
# @amount The amount of liquidity
func update_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt, amount : felt
) -> ():
    # TODO compute the current reward
    # TODO update the liquidity of the owner
    let (liquidity) = storage_liquidity.read(instrument)
    let new_liquidity = liquidity + amount
    storage_liquidity.write(instrument, new_liquidity)

    let (user_liquidity) = storage_user_liquidity.read(owner, instrument)
    let new_liquidity = user_liquidity + amount
    storage_user_liquidity.write(owner, instrument, new_liquidity)
    return ()
end
