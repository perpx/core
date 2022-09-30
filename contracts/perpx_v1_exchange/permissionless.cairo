%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_contract_address
from starkware.cairo.common.math import assert_le, unsigned_div_rem
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
// TODO update
func liquidate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(owner: felt) {
    // let (_price) = storage_price.read()
    // let (_fee) = storage_fee.read()
    // let (_delta) = liquidate_position(address=owner, price=_price, fee_bps=_fee)
    // Liquidate.emit(owner=owner, price=_price, fee=_fee, delta=_delta)
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
