%lang starknet

from contracts.library.position import Info, position, update_position, close_position
from contracts.library.vault import Vault

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import assert_nn

#
# Storage
#

@storage_var
func storage_longs(instrument : felt) -> (amount : felt):
end

@storage_var
func storage_shorts(instrument : felt) -> (amount : felt):
end

#
# Functions
#

# @notice Returns the notional amount of longs for the instrument
# @param instrument The instrument's id
# @return amount The notional amount of longs for the instrument
func longs{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (amount : felt):
    let (amount) = storage_longs.read(instrument)
    return (amount=amount)
end

# @notice Returns the notional amount of shorts for the instrument
# @param instrument The instrument's id
# @return amount The notional amount of shorts for the instrument
func shorts{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (amount : felt):
    let (amount) = storage_shorts.read(instrument)
    return (amount=amount)
end

# @notice Update long or short notional amount
# @dev Internal functions
# @param amount The amount of liquidity (precision: 6)
# @param price The price of the instrument
# @param instrument The instrument's id
# @param is_long The direction of the open interest update
func update_long_short{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt, is_long : felt
) -> ():
    tempvar value = amount
    if is_long == 1:
        let (longs) = storage_longs.read(instrument)
        tempvar new_longs = amount + longs

        with_attr error_message("negative longs"):
            assert_nn(new_longs)
        end

        storage_longs.write(instrument, new_longs)
        return ()
    else:
        let (shorts) = storage_shorts.read(instrument)
        tempvar new_shorts = amount + shorts

        with_attr error_message("negative shorts"):
            assert_nn(new_shorts)
        end

        storage_shorts.write(instrument, new_shorts)
        return ()
    end
end

# @notice Update the pool's liquidity
# @dev Internal functions
# @param amount The amount of liquidity (precision: 6)
# @param owner The liquidity provider
# @param instrument The instrument's id
func update_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, owner : felt, instrument : felt
) -> ():
    tempvar value = amount
    tempvar is_positive : felt
    %{
        from starkware.cairo.common.math_utils import is_positive
        ids.is_positive = 1 if is_positive(
            value=ids.value, prime=PRIME, rc_bound=range_check_builtin.bound) else 0
    %}
    if is_positive == 1:
        Vault.provide_liquidity(amount=amount, owner=owner, instrument=instrument)
    else:
        Vault.withdraw_liquidity(amount=-amount, owner=owner, instrument=instrument)
    end
    return ()
end
