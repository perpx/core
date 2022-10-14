%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_le, unsigned_div_rem, signed_div_rem, assert_not_zero
from starkware.cairo.common.math_cmp import is_nn, is_le
from starkware.cairo.common.uint256 import Uint256

from contracts.perpx_v1_exchange.storage import (
    storage_user_instruments,
    storage_oracles,
    storage_collateral,
    storage_token,
    storage_operations_queue,
    storage_operations_count,
    storage_queue_limit,
)
from contracts.perpx_v1_exchange.internals import (
    _calculate_pnl,
    _calculate_exit_fees,
    _calculate_fees,
    _calculate_margin_requirement,
    _close_all_positions,
    _divide_margin,
    _verify_instrument,
)
from contracts.constants.perpx_constants import (
    LIMIT,
    MAX_BOUND,
    MAX_LIQUIDATOR_PAY_OUT,
    MIN_LIQUIDATOR_PAY_OUT,
)
from contracts.perpx_v1_exchange.structures import QueuedOperation, Operation
from contracts.perpx_v1_instrument import update_liquidity
from contracts.perpx_v1_exchange.events import Liquidate, Trade
from contracts.library.position import Position, Info
from contracts.library.vault import storage_liquidity
from contracts.library.vault import Stake, storage_user_stake

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
// PERMISSIONLESS
//

// @notice Add the trading order to the operation queue
// @param amount The amount to trade
// @param instrument The instrument to trade
// @param valid_until The validity timestamp of the closing order
@external
func trade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt, valid_until: felt
) -> () {
    alloc_locals;
    local limit = LIMIT;
    let (count) = storage_operations_count.read();
    let (queue_limit) = storage_queue_limit.read();
    // check the limits
    _verify_instrument(instrument=instrument);
    let (local caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }
    with_attr error_message("trading amount limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;
    with_attr error_message("invalid expiration timestamp") {
        assert [range_check_ptr] = valid_until - 1;
        assert [range_check_ptr + 1] = LIMIT - valid_until;
    }
    let range_check_ptr = range_check_ptr + 2;
    with_attr error_message("queue size limit reached") {
        assert_le(count + 1, queue_limit);
    }

    storage_operations_queue.write(
        count,
        QueuedOperation(caller=caller, amount=amount, instrument=instrument, valid_until=valid_until, operation=Operation.trade),
    );
    storage_operations_count.write(count + 1);
    return ();
}

// @notice Add the closing of the position of the owner to the queue
// @param instrument The instrument for which to close the position
// @param valid_until The validity timestamp of the closing order
func close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt, valid_until: felt
) {
    alloc_locals;
    local limit = LIMIT;
    let (count) = storage_operations_count.read();
    let (queue_limit) = storage_queue_limit.read();
    // check the limits
    _verify_instrument(instrument=instrument);
    let (local caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }
    with_attr error_message("invalid expiration timestamp") {
        assert [range_check_ptr] = valid_until - 1;
        assert [range_check_ptr + 1] = LIMIT - valid_until;
    }
    let range_check_ptr = range_check_ptr + 2;
    with_attr error_message("queue size limit reached") {
        assert_le(count + 1, queue_limit);
    }

    storage_operations_queue.write(
        count,
        QueuedOperation(caller=caller, amount=0, instrument=instrument, valid_until=valid_until, operation=Operation.close),
    );
    storage_operations_count.write(count + 1);
    return ();
}

// @notice Liquidate all positions of owner
// @param owner The owner of the positions
@external
func liquidate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    // check the user is exposed
    // (collateral_remaining + PnL - fees - exit_imbalance_fees) > Sum(value_at_risk*k*sigma)
    alloc_locals;
    with_attr error_message("user cannot be the zero address") {
        assert_not_zero(owner);
    }
    let (collateral) = storage_collateral.read(owner);
    let (local instruments) = storage_user_instruments.read(owner);

    let (exit_fees) = _calculate_exit_fees(owner=owner, instruments=instruments, mult=1);
    let (fees) = _calculate_fees(owner=owner, instruments=instruments, mult=1);
    let (pnl) = _calculate_pnl(owner=owner, instruments=instruments, mult=1);

    tempvar margin = collateral + pnl - fees - exit_fees;
    let (min_margin) = _calculate_margin_requirement(owner=owner, instruments=instruments, mult=1);

    with_attr error_message("cannot liquidate user, margin > min_margin") {
        assert_le(margin, min_margin - 1);
    }

    let (instrument_count) = _close_all_positions(
        owner=owner, instruments=instruments, instrument_count=0, mult=1
    );

    let (caller) = get_caller_address();
    let (token_address) = storage_token.read();
    let is_positive = is_nn(margin);

    if (is_positive == 1) {
        let is_ge_max_payout = is_le(MAX_LIQUIDATOR_PAY_OUT, margin);
        if (is_ge_max_payout == 1) {
            // if margin > MAX_LIQUIDATOR_PAY_OUT, distribute remainder to pools
            tempvar remainder = margin - MAX_LIQUIDATOR_PAY_OUT;
            let (q, r) = unsigned_div_rem(remainder, instrument_count);
            _divide_margin(total=remainder, amount=q, instruments=instruments, mult=1);
            // TODO improve the winnings distribution
            IERC20.transfer(
                contract_address=token_address,
                recipient=caller,
                amount=Uint256(MAX_LIQUIDATOR_PAY_OUT + r, 0),
            );
            Liquidate.emit(owner=owner, instruments=instruments);
            return ();
        }

        let is_ge_min_payout = is_le(MIN_LIQUIDATOR_PAY_OUT, margin);
        if (is_ge_min_payout == 1) {
            // if MIN_LIQUIDATOR_PAY_OUT < margin < MAX_LIQUIDATOR_PAY_OUT,
            // send all to keeper bot.
            IERC20.transfer(
                contract_address=token_address, recipient=caller, amount=Uint256(margin, 0)
            );
            Liquidate.emit(owner=owner, instruments=instruments);
            return ();
        }
        // If 0 < margin < MIN_LIQUIDATOR_PAY_OUT, send MLPAY.
        tempvar remainder = MIN_LIQUIDATOR_PAY_OUT - margin;
        let (q, r) = unsigned_div_rem(remainder, instrument_count);
        _divide_margin(total=remainder, amount=-q, instruments=instruments, mult=1);
        IERC20.transfer(
            contract_address=token_address,
            recipient=caller,
            amount=Uint256(MIN_LIQUIDATOR_PAY_OUT - r, 0),
        );
        Liquidate.emit(owner=owner, instruments=instruments);
        return ();
    } else {
        // if margin < 0, send minimum reward to keeper bot and distribute looses on pools
        let (q, r) = signed_div_rem(margin, instrument_count, MAX_BOUND);
        // TODO improve the loss distribution
        _divide_margin(total=-margin, amount=q, instruments=instruments, mult=1);
        IERC20.transfer(
            contract_address=token_address,
            recipient=caller,
            amount=Uint256(MIN_LIQUIDATOR_PAY_OUT - r, 0),
        );
        Liquidate.emit(owner=owner, instruments=instruments);
        return ();
    }
}

// @notice Add collateral for the owner
// @param amount The change in collateral
@external
func add_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(amount: felt) {
    alloc_locals;
    local limit = LIMIT;
    with_attr error_message("collateral increase limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }

    let (exchange) = get_contract_address();
    let (collateral) = storage_collateral.read(caller);

    with_attr error_message("collateral limited to {limit}") {
        assert [range_check_ptr] = amount + collateral;
        assert [range_check_ptr + 1] = LIMIT - amount - collateral;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (token_address) = storage_token.read();

    IERC20.transferFrom(
        contract_address=token_address, sender=caller, recipient=exchange, amount=Uint256(amount, 0)
    );

    storage_collateral.write(caller, amount + collateral);
    return ();
}

// @notice Add the collateral removal to the operations queue
// @param amount The change in collateral
// @param valid_until The validity timestamp of the collateral removal
@external
func remove_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, valid_until: felt
) {
    alloc_locals;
    local limit = LIMIT;
    let (count) = storage_operations_count.read();
    let (queue_limit) = storage_queue_limit.read();
    // check the limits
    let (local caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }
    with_attr error_message("collateral decrease limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;
    with_attr error_message("invalid expiration timestamp") {
        assert [range_check_ptr] = valid_until - 1;
        assert [range_check_ptr + 1] = LIMIT - valid_until;
    }
    let range_check_ptr = range_check_ptr + 2;
    with_attr error_message("queue size limit reached") {
        assert_le(count + 1, queue_limit);
    }

    storage_operations_queue.write(
        count,
        QueuedOperation(caller=caller, amount=amount, instrument=0, valid_until=valid_until, operation=Operation.remove_collateral),
    );
    storage_operations_count.write(count + 1);
    return ();
}

// @notice Add liquidity for the instrument
// @param amount The change in liquidity
// @param instrument The instrument to add liquidity for
@external
func add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instrument: felt
) -> () {
    alloc_locals;
    local limit = LIMIT;
    _verify_instrument(instrument=instrument);
    with_attr error_message("liquidity increase limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }

    let (exchange) = get_contract_address();
    let (stake: Stake) = storage_user_stake.read(caller, instrument);

    let (liquidity) = storage_liquidity.read(instrument);
    with_attr error_message("liquidity limited to {limit}") {
        assert [range_check_ptr] = amount + liquidity;
        assert [range_check_ptr + 1] = LIMIT - amount - liquidity;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (token_address) = storage_token.read();
    IERC20.transferFrom(
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
    local limit = LIMIT;
    _verify_instrument(instrument=instrument);
    with_attr error_message("liquidity decrease limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (local caller) = get_caller_address();
    with_attr error_message("caller is the zero address") {
        assert_not_zero(caller);
    }

    update_liquidity(amount=-amount, owner=caller, instrument=instrument);

    let (exchange) = get_contract_address();
    let (token_address) = storage_token.read();
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0));

    return ();
}
