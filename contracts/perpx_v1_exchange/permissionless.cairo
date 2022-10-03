%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_le, unsigned_div_rem, signed_div_rem
from starkware.cairo.common.math_cmp import is_nn, is_le
from starkware.cairo.common.uint256 import Uint256

from contracts.perpx_v1_exchange.storage import (
    storage_user_instruments,
    storage_oracles,
    storage_collateral,
    storage_token,
)
from contracts.perpx_v1_exchange.internals import (
    _calculate_pnl,
    _calculate_exit_fees,
    _calculate_fees,
    _calculate_margin_requirement,
)
from contracts.constants.perpx_constants import (
    LIMIT,
    MAX_BOUND,
    MAX_LIQUIDATOR_PAY_OUT,
    MIN_LIQUIDATOR_PAY_OUT,
)
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
func close{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(instrument: felt) {
    // let (_price) = storage_price.read()
    // let (_delta) = settle_position(address=owner, price=_price)
    // Close.emit(owner=owner, price=_price, delta=_delta)
    return ();
}

// @notice Liquidate all positions of owner
// @param owner The owner of the positions
@external
func liquidate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    // check the user is exposed
    // (collateral_remaining + PnL - fees - exit_imbalance_fees) > Sum(value_at_risk*k*sigma)
    alloc_locals;
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
            _divide_margin(amount=q, instruments=instruments, mult=1);
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
        _divide_margin(amount=-q, instruments=instruments, mult=1);
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
        _divide_margin(amount=q, instruments=instruments, mult=1);
        IERC20.transfer(
            contract_address=token_address,
            recipient=caller,
            amount=Uint256(MIN_LIQUIDATOR_PAY_OUT - r, 0),
        );
        Liquidate.emit(owner=owner, instruments=instruments);
        return ();
    }
}

// @notice Closes all the users positions
// @param owner The owner of the positions
// @param instruments The instruments owned by the owner
// @param instrument_count The count of instruments
// @param mult The multiplication factor
func _close_all_positions{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instruments: felt, instrument_count: felt, mult: felt
) -> (instrument_count: felt) {
    alloc_locals;
    if (instruments == 0) {
        return (instrument_count=instrument_count);
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (price) = storage_oracles.read(instrument=mult);
        let (_) = Position.close_position(owner=owner, instrument=mult, price=price, fees=0);

        let (count) = _close_all_positions(
            owner=owner, instruments=q, instrument_count=instrument_count + 1, mult=mult * 2
        );
        return (instrument_count=count);
    }
    let (count) = _close_all_positions(
        owner=owner, instruments=q, instrument_count=instrument_count, mult=mult * 2
    );
    return (instrument_count=count);
}

// @notice Divides margin accross the instruments
// @param amount The amount to change the liquidity by
// @param instruments The instruments owned by the owner
// @param mult The multiplication factor
// TODO add way to determine if margin substraction was successful
func _divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt, instruments: felt, mult: felt
) {
    alloc_locals;
    if (instruments == 0) {
        return ();
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (liquidity) = storage_liquidity.read(mult);
        storage_liquidity.write(mult, liquidity + amount);
        _divide_margin(amount=amount, instruments=q, mult=mult * 2);
        return ();
    }
    _divide_margin(amount=amount, instruments=q, mult=mult * 2);
    return ();
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

// @notice Remove collateral for the owner
// @param amount The change in collateral
@external
func remove_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    local limit = LIMIT;
    // check the limits
    with_attr error_message("collateral decrease limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    // check the user can remove this much collateral
    let (local caller) = get_caller_address();
    let (collateral) = storage_collateral.read(caller);
    let new_collateral = collateral - amount;

    with_attr error_message("insufficient collateral") {
        assert [range_check_ptr] = new_collateral;
    }
    let range_check_ptr = range_check_ptr + 1;

    // check the user is not exposed by removing this much collateral
    // (collateral_remaining + PnL - fees - exit_imbalance_fees) > Sum(value_at_risk*k*sigma)
    let (instruments) = storage_user_instruments.read(caller);
    let (exit_fees) = _calculate_exit_fees(owner=caller, instruments=instruments, mult=1);
    let (fees) = _calculate_fees(owner=caller, instruments=instruments, mult=1);
    let (pnl) = _calculate_pnl(owner=caller, instruments=instruments, mult=1);
    tempvar margin = new_collateral + pnl - fees - exit_fees;
    let (min_margin) = _calculate_margin_requirement(owner=caller, instruments=instruments, mult=1);

    with_attr error_message("insufficient collateral") {
        assert_le(min_margin, margin);
    }
    storage_collateral.write(caller, new_collateral);

    let (exchange) = get_contract_address();
    let (token_address) = storage_token.read();
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0));

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
    with_attr error_message("liquidity increase limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (caller) = get_caller_address();
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
    with_attr error_message("liquidity decrease limited to {limit}") {
        assert [range_check_ptr] = amount - 1;
        assert [range_check_ptr + 1] = LIMIT - amount;
    }
    let range_check_ptr = range_check_ptr + 2;

    let (local caller) = get_caller_address();
    update_liquidity(amount=-amount, owner=caller, instrument=instrument);

    let (exchange) = get_contract_address();
    let (token_address) = storage_token.read();
    IERC20.transfer(contract_address=token_address, recipient=caller, amount=Uint256(amount, 0));

    return ();
}
