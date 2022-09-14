%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.uint256 import Uint256

from lib.cairo_math_64x61.contracts.cairo_math_64x61.math64x61 import Math64x61
from contracts.library.position import Position
from contracts.library.vault import Stake, Vault
from contracts.utils.access_control import init_access_control, assert_only_owner
from contracts.constants.perpx_constants import MAX_LIQUIDITY, MAX_COLLATERAL, LIQUIDITY_PRECISION
from contracts.perpx_v1_instrument import update_liquidity

//
// Structures
//

struct BatchedTrade {
    valid_until: felt,
    amount: felt,
}

struct BatchedCollateral {
    valid_until: felt,
    amount: felt,
}

// k and lambda are stored as fixed point values 64x61
struct Parameter {
    k: felt,
    lambda: felt,
}

//
// Interfaces
//
@contract_interface
namespace IERC20 {
    func transfer(recipient: felt, amount: Uint256) {
    }
    func transfer_from(sender: felt, recipient: felt, amount: Uint256) {
    }
}

//
// Events
//

@event
func Trade(owner: felt, instrument: felt, price: felt, amount: felt, fee: felt) {
}

@event
func Close(owner: felt, instrument: felt, price: felt, fee: felt, delta: felt) {
}

@event
func Liquidate(owner: felt) {
}

@event
func UpdateCollateral(owner: felt, amount: felt) {
}

@event
func UpdateLiquidity(owner: felt, amount: felt) {
}

//
// Storage
//

@storage_var
func storage_user_instruments(owner: felt) -> (instruments: felt) {
}

@storage_var
func storage_oracles(instrument: felt) -> (price: felt) {
}

@storage_var
func storage_prev_oracles(instrument: felt) -> (price: felt) {
}

@storage_var
func storage_volatility(instrument: felt) -> (volatility: felt) {
}

@storage_var
func storage_margin_parameters(instrument: felt) -> (param: Parameter) {
}

@storage_var
func storage_collateral(owner: felt) -> (amount: felt) {
}

@storage_var
func storage_trades_queue(index: felt) -> (trade: BatchedTrade) {
}

@storage_var
func storage_trades_count() -> (count: felt) {
}

@storage_var
func storage_collateral_queue(index: felt) -> (collateral: BatchedCollateral) {
}

@storage_var
func storage_collateral_count() -> (count: felt) {
}

@storage_var
func storage_token() -> (address: felt) {
}

@storage_var
func storage_instrument_count() -> (instrument_count: felt) {
}

@storage_var
func is_paused() -> (paused: felt) {
}

//
// Constructor
//

// @notice Exchange constructor
// @param owner The contract owner
// @param token The collateral token address
// @param instrument_count The number of instruments
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, token: felt, instrument_count: felt
) {
    init_access_control(owner);
    storage_token.write(token);
    storage_instrument_count.write(instrument_count);
    return ();
}

//
// PERMISSIONLESS
//

// @notice Trade an amount of the index
// @param amount The amount to trade
// @param instrument The instrument to trade
@external
func trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt
) -> () {
    alloc_locals;
    // TODO check price and amount limits
    // TODO calculate owner pnl to check if he can trade this amount (must be X % over collateral)
    let (local owner) = get_caller_address();
    let (instruments) = storage_user_instruments.read(owner);
    let (pnl) = _calculate_pnl(owner=owner, instruments=instruments, mult=1);
    // TODO batch the trade
    let (price) = storage_oracles.read(instrument);
    // TODO change the fee
    Trade.emit(owner=owner, instrument=instrument, price=price, amount=amount, fee=0);
    return ();
}

// @notice Close the position of the owner, set fees and pnl to zero
// @param instrument The instrument for which to close the position
// TODO update
func close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(instrument: felt) -> (
    delta: felt
) {
    // let (_price) = storage_price.read()
    // let (_delta) = settle_position(address=owner, price=_price)
    // Close.emit(owner=owner, price=_price, delta=_delta)
    return (delta=0);
}

// @notice Liquidate all positions of owner
// @param owner The owner of the positions
// TODO update
func liquidate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) -> (
    delta: felt
) {
    // let (_price) = storage_price.read()
    // let (_fee) = storage_fee.read()
    // let (_delta) = liquidate_position(address=owner, price=_price, fee_bps=_fee)
    // Liquidate.emit(owner=owner, price=_price, fee=_fee, delta=_delta)
    return (delta=0);
}

// @notice Add collateral for the owner
// @param amount The change in collateral
@external
func add_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: felt) {
    with_attr error_message("collateral increase limited to 2**64") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = MAX_COLLATERAL - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (caller) = get_caller_address();
    let (exchange) = get_contract_address();
    let (collateral) = storage_collateral.read(caller);

    with_attr error_message("collateral limited to 2**64") {
        assert [range_check_ptr] = amount + collateral;
        assert [range_check_ptr + 1] = MAX_COLLATERAL - amount - collateral;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (token_address) = storage_token.read();

    IERC20.transfer_from(
        contract_address=token_address, sender=caller, recipient=exchange, amount=Uint256(amount, 0)
    );

    storage_collateral.write(caller, amount + collateral);
    return ();
}

// @notice Remove collateral for the owner
// @param amount The change in collateral
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

    return ();
}

// @notice Add liquidity for the instrument
// @param amount The change in liquidity
// @param instrument The instrument to add liquidity for
@external
func add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt
) -> () {
    with_attr error_message("liquidity increase limited to 2**64") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (caller) = get_caller_address();
    let (exchange) = get_contract_address();
    let (stake: Stake) = Vault.view_user_stake(caller, instrument);

    with_attr error_message("liquidity limited to 2**64") {
        assert [range_check_ptr] = amount + stake.amount;
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount - stake.amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (token_address) = storage_token.read();
    IERC20.transfer_from(
        contract_address=token_address, sender=caller, recipient=exchange, amount=Uint256(amount, 0)
    );
    update_liquidity(amount=amount, owner=caller, instrument=instrument);

    return ();
}

// @notice Remove liquidity for the instrument
// @param amount The change in liquidity
// @param instrument The instrument to remove liquidity for
@external
func remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt
) -> () {
    alloc_locals;
    with_attr error_message("liquidity decrease limited to 2**64") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = MAX_LIQUIDITY - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (local caller) = get_caller_address();
    update_liquidity(amount=-amount, owner=caller, instrument=instrument);

    let (exchange) = get_contract_address();
    let (token_address) = storage_token.read();
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0));

    return ();
}

//
// MUTABLE
//

// @notice Returns instruments for which user has a position
// @param owner The owner of the positions
// @return instruments The owner's instruments
func get_user_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt
) -> (instruments: felt) {
    let (instruments) = storage_user_instruments.read(owner);
    return (instruments=instruments);
}

// @notice Returns the price of the instrument
// @param instrument The instrument
// @return price The oracle's price for the instrument
func get_price{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) -> (price: felt) {
    let (price) = storage_oracles.read(instrument);
    return (price=price);
}

// @notice Returns the amount of collateral for the instrument
// @param owner The owner of the collateral
// @param instrument The collateral's instrument
// @return collateral The amount of collateral for the instrument
func get_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instrument: felt
) -> (collateral: felt) {
    let (collateral) = storage_collateral.read(owner, instrument);
    return (collateral=collateral);
}

// @notice Returns the number of instruments
// @return count The number of instruments on the exchange
func get_instrument_count{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (
    count: felt
) {
    let (count) = storage_instrument_count.read();
    return (count=count);
}

//
// OWNER
//

// @notice Update the prices of the instruments
// @param prices_len The number of instruments to update
// @param prices The prices of the instruments to update
// @param instruments The instruments to update
// @dev If the list of instruments is [A, B, C, D, E, F, G] and prices update
// @dev apply to [A, E, G], instruments = 2^0 + 2^4 + 2^6
func update_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prices_len: felt, prices: felt*, instruments: felt
) -> () {
    assert_only_owner();
    _verify_length(length=prices_len, instruments=instruments);
    _update_prices(
        prices_len=prices_len, prices=prices, mult=1, instrument=0, instruments=instruments
    );
    let (count) = storage_instrument_count.read();
    _update_volatility(instrument_count=count, mult=1);
    return ();
}

// @notice Update the margin parameters
// @param parameters_len The number of parameters to update
// @param parameters The parameters to update
// @param instruments The instruments to update
// @dev If the list of instruments is [A, B, C, D, E, F, G] and margin update
// @dev apply to [A, E, G], instruments = 2^0 + 2^4 + 2^6
func update_margin_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    parameters_len: felt, parameters: Parameter*, instruments: felt
) -> () {
    assert_only_owner();
    _verify_length(length=parameters_len, instruments=instruments);
    _update_margin_parameters(
        parameters_len=parameters_len, parameters=parameters, mult=1, instruments=instruments
    );
    return ();
}

// @notice Update the prices of the oracles
// @param prices_len Number of prices to update
// @param prices The price updates
// @param mult The multiplication factor
// @param instrument The current instrument
// @param instruments The instruments to update
func _update_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prices_len: felt, prices: felt*, mult: felt, instrument: felt, instruments: felt
) -> () {
    alloc_locals;
    let (count) = storage_instrument_count.read();
    if (instrument == count) {
        return ();
    }
    let (prev_price) = storage_oracles.read(mult);
    storage_prev_oracles.write(mult, prev_price);

    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        storage_oracles.write(mult, [prices]);
        _update_prices(
            prices_len=prices_len - 1,
            prices=prices + 1,
            mult=mult * 2,
            instrument=instrument + 1,
            instruments=q,
        );
    } else {
        _update_prices(
            prices_len=prices_len,
            prices=prices,
            mult=mult * 2,
            instrument=instrument + 1,
            instruments=q,
        );
    }
    return ();
}

// @notice Update the margin parameters
// @param parameters_len The number of parameters to update
// @param parameters The parameters to update
// @param instruments The instruments to update
// @param mult The multiplication factor
// @param instruments The instruments to update
func _update_margin_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    parameters_len: felt, parameters: Parameter*, mult: felt, instruments: felt
) -> () {
    alloc_locals;
    if (instruments == 0) {
        return ();
    }

    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        storage_margin_parameters.write(mult, [parameters]);
        _update_margin_parameters(
            parameters_len=parameters_len - 1,
            parameters=parameters + 2,
            mult=mult * 2,
            instruments=q,
        );
    } else {
        _update_margin_parameters(
            parameters_len=parameters_len, parameters=parameters, mult=mult * 2, instruments=q
        );
    }
    return ();
}

func _update_volatility{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument_count: felt, mult: felt
) -> () {
    alloc_locals;
    if (instrument_count == 0) {
        return ();
    }
    let (price) = storage_oracles.read(mult);
    let (prev_price) = storage_prev_oracles.read(mult);
    let (price64x61) = Math64x61.fromFelt(price);
    let (prev_price64x61) = Math64x61.fromFelt(prev_price);

    // truncate by price precision (6)
    let (price64x61, _) = unsigned_div_rem(price64x61, LIQUIDITY_PRECISION);
    let (prev_price64x61, _) = unsigned_div_rem(prev_price64x61, LIQUIDITY_PRECISION);
    let (price_return) = Math64x61.div(price64x61, prev_price64x61);

    let (log_price_return) = Math64x61.log10(price_return);
    let (exponant) = Math64x61.fromFelt(2);
    let (square_log_price_return) = Math64x61.pow(log_price_return, exponant);

    let (old_volatility) = storage_volatility.read(mult);
    let (params) = storage_margin_parameters.read(mult);

    let (new_volatility) = Math64x61.mul(params.lambda, old_volatility);
    let (new_volatility) = Math64x61.add(new_volatility, square_log_price_return);
    storage_volatility.write(mult, new_volatility);
    _update_volatility(instrument_count=instrument_count - 1, mult=mult * 2);
    return ();
}

// @notice Initiate previous prices for volatility calculation
// @param prev_prices_len The length of the previous prices array
// @param prev_prices The previous prices
func init_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_prices_len: felt, prev_prices: felt*
) {
    assert_only_owner();
    let (count) = storage_instrument_count.read();
    assert count = prev_prices_len;
    _init_prev_prices(prev_prices_len=prev_prices_len, prev_prices=prev_prices, mult=1);
    return ();
}

func _init_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_prices_len: felt, prev_prices: felt*, mult: felt
) {
    if (prev_prices_len == 0) {
        return ();
    }
    storage_prev_oracles.write(mult, [prev_prices]);
    _init_prev_prices(
        prev_prices_len=prev_prices_len - 1, prev_prices=prev_prices + 1, mult=mult * 2
    );
    return ();
}

//
// Internal
//

// @notice Calculates the owner pnl
// @dev Internal function
// @param owner The owner of the positions
// @param instruments The instruments traded by owner
// @param mult The multiplication factor
// @return pnl The pnl of the owner
func _calculate_pnl{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instruments: felt, mult: felt
) -> (pnl: felt) {
    alloc_locals;
    if (instruments == 0) {
        return (pnl=0);
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (price) = storage_oracles.read(mult);
        let (info) = Position.position(owner, mult);
        let new_pnl = price * info.size - info.cost;
        let (p) = _calculate_pnl(owner=owner, instruments=q, mult=mult * 2);
        return (pnl=p + new_pnl);
    }
    let (p) = _calculate_pnl(owner=owner, instruments=q, mult=mult * 2);
    return (pnl=p);
}

// @notice Calculates the owner fees
// @dev Internal function
// @param owner The owner of the positions
// @param instruments The instruments traded by owner
// @return fees The fees of the owner
func _calculate_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instruments: felt, mult: felt
) -> (fees: felt) {
    alloc_locals;
    if (instruments == 0) {
        return (fees=0);
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (info) = Position.position(owner, mult);
        let new_fees = info.fees;
        let (f) = _calculate_fees(owner=owner, instruments=q, mult=mult * 2);
        return (fees=f + new_fees);
    }
    let (f) = _calculate_fees(owner=owner, instruments=q, mult=mult * 2);
    return (fees=f);
}

// @notice Verify the length of the array matches the number of instruments updated
// @param length The length of the array
// @param instruments The instruments updated
func _verify_length{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    length: felt, instruments: felt
) -> () {
    alloc_locals;
    if (instruments == 0) {
        assert length = 0;
        return ();
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        _verify_length(length=length - 1, instruments=q);
    } else {
        _verify_length(length=length, instruments=q);
    }
    return ();
}
