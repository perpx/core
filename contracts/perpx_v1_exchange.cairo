%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256

from contracts.library.position import Position
from contracts.library.vault import Stake, Vault
from contracts.utils.access_control import init_access_control, assert_only_owner
from contracts.constants.perpx_constants import MAX_LIQUIDITY, MAX_COLLATERAL
from contracts.perpx_v1_instrument import update_liquidity

#
# Structures
#

struct BatchedTrade:
    member valid_until : felt
    member amount : felt
end

struct BatchedCollateral:
    member valid_until : felt
    member amount : felt
end

#
# Interfaces
#
@contract_interface
namespace IERC20:
    func transfer(recipient : felt, amount : Uint256):
    end
    func transfer_from(sender : felt, recipient : felt, amount : Uint256):
    end
end

#
# Events
#

@event
func Trade(owner : felt, instrument : felt, price : felt, amount : felt, fee : felt):
end

@event
func Close(owner : felt, instrument : felt, price : felt, fee : felt, delta : felt):
end

@event
func Liquidate(owner : felt):
end

@event
func UpdateCollateral(owner : felt, amount : felt):
end

@event
func UpdateLiquidity(owner : felt, amount : felt):
end

#
# Storage
#

@storage_var
func storage_user_instruments(owner : felt) -> (instruments : felt):
end

@storage_var
func storage_oracles(instrument : felt) -> (price : felt):
end

@storage_var
func storage_collateral(owner : felt) -> (amount : felt):
end

@storage_var
func storage_trades_queue(index : felt) -> (trade : BatchedTrade):
end
@storage_var
func storage_trades_count() -> (count : felt):
end

@storage_var
func storage_collateral_queue(index : felt) -> (collateral : BatchedCollateral):
end
@storage_var
func storage_collateral_count() -> (count : felt):
end

@storage_var
func storage_token() -> (address : felt):
end

@storage_var
func storage_instrument_count() -> (instrument_count : felt):
end

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, token : felt, instrument_count : felt
):
    init_access_control(owner)
    storage_token.write(token)
    storage_instrument_count.write(instrument_count)
    return ()
end

#
# PERMISSIONLESS
#

# @notice Trade an amount of the index
# @param amount The amount to trade
# @param instrument The instrument to trade
@external
func trade{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt
) -> ():
    alloc_locals
    # TODO check price and amount limits
    # TODO calculate owner pnl to check if he can trade this amount (must be X % over collateral)
    let (local owner) = get_caller_address()
    let (instruments) = storage_user_instruments.read(owner)
    let (pnl) = calculate_pnl(owner=owner, instruments=instruments, mult=1)
    # TODO batch the trade
    let (price) = storage_oracles.read(instrument)
    # TODO change the fee
    Trade.emit(owner=owner, instrument=instrument, price=price, amount=amount, fee=0)
    return ()
end

# @notice Close the position of the owner, set fees and pnl to zero
# @param instrument The instrument for which to close the position
# TODO update
func close{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (delta : felt):
    # let (_price) = storage_price.read()
    # let (_delta) = settle_position(address=owner, price=_price)
    # Close.emit(owner=owner, price=_price, delta=_delta)
    return (delta=0)
end

# @notice Liquidate all positions of owner
# @param owner The owner of the positions
# TODO update
func liquidate{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(owner : felt) -> (
    delta : felt
):
    # let (_price) = storage_price.read()
    # let (_fee) = storage_fee.read()
    # let (_delta) = liquidate_position(address=owner, price=_price, fee_bps=_fee)
    # Liquidate.emit(owner=owner, price=_price, fee=_fee, delta=_delta)
    return (delta=0)
end

# @notice Add collateral for the owner
# @param amount The change in collateral
@external
func add_collateral{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt
):
    with_attr error_message("collateral increase limited to 2**64"):
        assert [range_check_ptr] = amount - 1
        assert [range_check_ptr + 1] = MAX_COLLATERAL - amount
    end
    let range_check_ptr = range_check_ptr + 2

    let (caller) = get_caller_address()
    let (exchange) = get_contract_address()
    let (collateral) = storage_collateral.read(caller)

    with_attr error_message("collateral limited to 2**64"):
        assert [range_check_ptr] = amount + collateral
        assert [range_check_ptr + 1] = MAX_COLLATERAL - amount - collateral
    end
    let range_check_ptr = range_check_ptr + 2

    let (token_address) = storage_token.read()

    IERC20.transfer_from(
        contract_address=token_address, sender=caller, recipient=exchange, amount=Uint256(amount, 0)
    )

    storage_collateral.write(caller, amount + collateral)
    return ()
end

# @notice Remove collateral for the owner
# @param amount The change in collateral
@external
func remove_collateral{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt
):
    with_attr error_message("collateral decrease limited to 2**64"):
        assert [range_check_ptr] = amount - 1
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount
    end
    let range_check_ptr = range_check_ptr + 2
    return ()
end

# @notice Add liquidity for the instrument
# @param amount The change in liquidity
# @param instrument The instrument to add liquidity for
@external
func add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt
) -> ():
    with_attr error_message("liquidity increase limited to 2**64"):
        assert [range_check_ptr] = amount - 1
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount
    end
    let range_check_ptr = range_check_ptr + 2

    let (caller) = get_caller_address()
    let (exchange) = get_contract_address()
    let (stake : Stake) = Vault.view_user_stake(caller, instrument)

    with_attr error_message("liquidity limited to 2**64"):
        assert [range_check_ptr] = amount + stake.amount
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount - stake.amount
    end
    let range_check_ptr = range_check_ptr + 2

    let (token_address) = storage_token.read()
    IERC20.transfer_from(
        contract_address=token_address, sender=caller, recipient=exchange, amount=Uint256(amount, 0)
    )
    update_liquidity(amount=amount, owner=caller, instrument=instrument)

    return ()
end

# @notice Remove liquidity for the instrument
# @param amount The change in liquidity
# @param instrument The instrument to remove liquidity for
@external
func remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt
) -> ():
    alloc_locals
    with_attr error_message("liquidity decrease limited to 2**64"):
        assert [range_check_ptr] = amount - 1
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount
    end
    let range_check_ptr = range_check_ptr + 2

    let (local caller) = get_caller_address()
    update_liquidity(amount=-amount, owner=caller, instrument=instrument)

    let (exchange) = get_contract_address()
    let (token_address) = storage_token.read()
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0))

    return ()
end

#
# MUTABLE
#

# @notice Returns instruments for which user has a position
# @param owner The owner of the positions
# @return instruments The owner's instruments
func get_user_instruments{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt
) -> (instruments : felt):
    let (instruments) = storage_user_instruments.read(owner)
    return (instruments=instruments)
end

# @notice Returns the price of the instrument
# @param instrument The instrument
# @return price The oracle's price for the instrument
func get_price{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (price : felt):
    let (price) = storage_oracles.read(instrument)
    return (price=price)
end

# @notice Returns the amount of collateral for the instrument
# @param owner The owner of the collateral
# @param instrument The collateral's instrument
# @return collateral The amount of collateral for the instrument
func get_collateral{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt
) -> (collateral : felt):
    let (collateral) = storage_collateral.read(owner, instrument)
    return (collateral=collateral)
end

# @notice Returns the number of instruments
# @return count The number of instruments on the exchange
func get_instrument_count{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    count : felt
):
    let (count) = storage_instrument_count.read()
    return (count=count)
end

#
# OWNER
#

# @notice Update the prices of the instruments
# @param prices_len The number of instruments to update
# @param prices The prices of the instruments to update
# @param instruments The instruments to update
# @dev If the list of instruments is [A, B, C, D, E, F, G] and prices update
# @dev apply to [A, E, G], instruments = 2^0 + 2^4 + 2^6
func update_prices{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prices_len : felt, prices : felt*, instruments : felt
) -> ():
    assert_only_owner()
    verify_length(length=prices_len, instruments=instruments)
    _update_prices(prices_len=prices_len, prices=prices, mult=1, instruments=instruments)
    return ()
end

# @notice Verify the length of the array matches the number of instruments updated
# @param length The length of the array
# @param instruments The instruments updated
func verify_length{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    length : felt, instruments : felt
) -> ():
    alloc_locals
    if instruments == 0:
        assert length = 0
        return ()
    end
    let (q, r) = unsigned_div_rem(instruments, 2)
    if r == 1:
        verify_length(length=length - 1, instruments=q)
    else:
        verify_length(length=length, instruments=q)
    end
    return ()
end

# @notice Update the prices of the oracles
# @param prices_len Number of prices to update
# @param prices The price updates
# @param mult The multiplication factor
# @param instruments The instruments to update
func _update_prices{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prices_len : felt, prices : felt*, mult : felt, instruments : felt
) -> ():
    alloc_locals
    if instruments == 0:
        return ()
    end
    let (q, r) = unsigned_div_rem(instruments, 2)
    if r == 1:
        storage_oracles.write(mult, [prices])
        _update_prices(prices_len=prices_len - 1, prices=prices + 1, mult=mult * 2, instruments=q)
    else:
        _update_prices(prices_len=prices_len, prices=prices, mult=mult * 2, instruments=q)
    end
    return ()
end

#
# Internal
#

# @notice Calculates the owner pnl
# @dev Internal function
# @param owner The owner of the positions
# @param instruments The instruments traded by owner
# @param mult The multiplication factor
# @return pnl The pnl of the owner
func calculate_pnl{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instruments : felt, mult : felt
) -> (pnl : felt):
    alloc_locals
    if instruments == 0:
        return (pnl=0)
    end
    let (q, r) = unsigned_div_rem(instruments, 2)
    if r == 1:
        let (price) = storage_oracles.read(mult)
        let (info) = Position.position(owner, mult)
        let new_pnl = price * info.size - info.cost
        let (p) = calculate_pnl(owner=owner, instruments=q, mult=mult * 2)
        return (pnl=p + new_pnl)
    end
    let (p) = calculate_pnl(owner=owner, instruments=q, mult=mult * 2)
    return (pnl=p)
end

# @notice Calculates the owner fees
# @dev Internal function
# @param owner The owner of the positions
# @param instruments The instruments traded by owner
# @return fees The fees of the owner
func calculate_fees{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instruments : felt, mult : felt
) -> (fees : felt):
    alloc_locals
    if instruments == 0:
        return (fees=0)
    end
    let (q, r) = unsigned_div_rem(instruments, 2)
    if r == 1:
        let (info) = Position.position(owner, mult)
        let new_fees = info.fees
        let (f) = calculate_fees(owner=owner, instruments=q, mult=mult * 2)
        return (fees=f + new_fees)
    end
    let (f) = calculate_fees(owner=owner, instruments=q, mult=mult * 2)
    return (fees=f)
end
