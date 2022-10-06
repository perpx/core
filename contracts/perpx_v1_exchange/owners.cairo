%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math_cmp import is_le, is_nn
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.uint256 import Uint256

from contracts.perpx_v1_exchange.storage import (
    storage_instrument_count,
    storage_user_instruments,
    storage_oracles,
    storage_prev_oracles,
    storage_collateral,
    storage_token,
    storage_margin_parameters,
    storage_volatility,
    storage_operations_queue,
    storage_operations_count,
)
from contracts.perpx_v1_exchange.internals import (
    _calculate_pnl,
    _calculate_exit_fees,
    _calculate_fees,
    _calculate_margin_requirement,
)
from contracts.perpx_v1_exchange.structures import Parameter, QueuedOperation
from contracts.perpx_v1_exchange.internals import _verify_length, _verify_instruments
from contracts.constants.perpx_constants import LIQUIDITY_PRECISION
from contracts.utils.access_control import assert_only_owner
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Interfaces
//
@contract_interface
namespace IERC20 {
    func transfer(recipient: felt, amount: Uint256) {
    }
    func transferFrom(sender: felt, recipient: felt, amount: Uint256) {
    }
}

//
// OWNER
//

// TODO pausing feature
// TODO add queues flushing feature

// @notice Update the prices of the instruments
// @param prices_len The number of instruments to update
// @param prices The prices of the instruments to update
// @param instruments The instruments to update
// @dev If the list of instruments is [A, B, C, D, E, F, G] and prices update
// @dev apply to [A, E, G], instruments = 2^0 + 2^4 + 2^6
@external
func update_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prices_len: felt, prices: felt*, instruments: felt
) -> () {
    assert_only_owner();
    _verify_instruments(instruments);
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
@external
func update_margin_parameters{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    parameters_len: felt, parameters: Parameter*, instruments: felt
) -> () {
    assert_only_owner();
    _verify_instruments(instruments);
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
    let price64x61 = Math64x61.fromFelt(price);
    let prev_price64x61 = Math64x61.fromFelt(prev_price);

    // truncate by price precision (6)
    let (price64x61, _) = unsigned_div_rem(price64x61, LIQUIDITY_PRECISION);
    let (prev_price64x61, _) = unsigned_div_rem(prev_price64x61, LIQUIDITY_PRECISION);
    let price_return = Math64x61.div(price64x61, prev_price64x61);

    let log_price_return = Math64x61.log10(price_return);
    let exponant = Math64x61.fromFelt(2);
    let square_log_price_return = Math64x61.pow(log_price_return, exponant);

    let (old_volatility) = storage_volatility.read(mult);
    let (params) = storage_margin_parameters.read(mult);

    let new_volatility = Math64x61.mul(params.lambda, old_volatility);
    let new_volatility = Math64x61.add(new_volatility, square_log_price_return);
    storage_volatility.write(mult, new_volatility);
    _update_volatility(instrument_count=instrument_count - 1, mult=mult * 2);
    return ();
}

// @notice Update previous prices for volatility calculation
// @param prev_prices_len The length of the previous prices array
// @param prev_prices The previous prices
@external
func update_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_prices_len: felt, prev_prices: felt*
) {
    assert_only_owner();
    let (count) = storage_instrument_count.read();
    assert count = prev_prices_len;
    _update_prev_prices(prev_prices_len=prev_prices_len, prev_prices=prev_prices, mult=1);
    return ();
}

func _update_prev_prices{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    prev_prices_len: felt, prev_prices: felt*, mult: felt
) {
    if (prev_prices_len == 0) {
        return ();
    }
    storage_prev_oracles.write(mult, [prev_prices]);
    _update_prev_prices(
        prev_prices_len=prev_prices_len - 1, prev_prices=prev_prices + 1, mult=mult * 2
    );
    return ();
}

// @notice Executes all pending operations in the queue
func _execute_queued_operations{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (count) = storage_operations_count.read();
    let ts = get_block_timestamp();
    _execute_queued_operations_loop(timestamp=ts, count=count, index=0);
    storage_operations_count.write(0);
    return ();
}

// @notice Loop executing all pending collateral removals
// @param timestamp The current timestamp
// @param count The total amount of collateral removals
// @param index The current index of collateral removal
// TODO test
func _execute_queued_operations_loop{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(timestamp: felt, count: felt, index: felt) {
    alloc_locals;
    if (count == index) {
        return ();
    }
    let (local operation: QueuedOperation) = storage_operations_queue.read(index);
    // skip if now > valid_until
    let is_valid_ts = is_le(timestamp, operation.valid_until);
    if (is_valid_ts == 0) {
        storage_operations_queue.write(index, QueuedOperation(0, 0, 0, 0, 0));
        _execute_queued_operations_loop(timestamp=timestamp, count=count, index=index + 1);
        return ();
    }

    local caller = operation.caller;
    let op = operation.operation;
    if (op == Operation.trade) {
        _trade(caller=caller, amount=operation.amount, instrument=operation.instrument);
        storage_operations_queue.write(index, QueuedOperation(0, 0, 0, 0, 0));
        _execute_queued_operations_loop(timestamp=timestamp, count=count, index=index + 1);
        return ();
    }
    if (op == Operation.close) {
        _close(caller=caller, amount=operation.amount);
        storage_operations_queue.write(index, QueuedOperation(0, 0, 0, 0, 0));
        _execute_queued_operations_loop(timestamp=timestamp, count=count, index=index + 1);
        return ();
    }
    if (op == Operation.remove_collateral) {
        _remove_collateral(caller=caller, amount=operation.amount);
        storage_operations_queue.write(index, QueuedOperation(0, 0, 0, 0, 0));
        _execute_queued_operations_loop(timestamp=timestamp, count=count, index=index + 1);
        return ();
    }
    return ();
}

// @notice Execute a trading order
// @param caller The user trading
// @param amount The amount of the trade (precision: 6)
// @param instrument The instrument to trade
// TODO implement
// TODO test
func _trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, amount: felt, instrument: felt
) {
    return ();
}

// @notice Execute the closing of a position
// @param caller The user closing the position
// @param instrument The instrument to close the position
// TODO implement
// TODO test
func _close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, instrument: felt
) {
    return ();
}

// @notice Remove the caller's collateral by amount
// @param caller The user removing collateral
// @param amount The amount of collateral to remove (precision: 6)
// TODO test
func _remove_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    caller: felt, amount: felt
) {
    alloc_locals;
    // check the user can remove this much collateral
    let (collateral) = storage_collateral.read(caller);
    let new_collateral = collateral - amount;

    let positive_collateral = is_nn(new_collateral);
    if (positive_collateral == 0) {
        return ();
    }

    // check the user is not exposed by removing this much collateral
    // (collateral_remaining + PnL - fees - exit_imbalance_fees) > Sum(value_at_risk*k*sigma)
    let (local instruments) = storage_user_instruments.read(caller);
    let (exit_fees) = _calculate_exit_fees(owner=caller, instruments=instruments, mult=1);
    let (fees) = _calculate_fees(owner=caller, instruments=instruments, mult=1);
    let (pnl) = _calculate_pnl(owner=caller, instruments=instruments, mult=1);
    tempvar margin = new_collateral + pnl - fees - exit_fees;
    let (min_margin) = _calculate_margin_requirement(owner=caller, instruments=instruments, mult=1);

    let valid_margin = is_le(min_margin, margin);
    if (valid_margin == 0) {
        return ();
    }

    storage_collateral.write(caller, new_collateral);
    let (exchange) = get_contract_address();
    let (token_address) = storage_token.read();
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0));
    return ();
}
