%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, abs_value
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.pow import pow

from contracts.perpx_v1_exchange.storage import (
    storage_oracles,
    storage_instrument_count,
    storage_margin_parameters,
    storage_volatility,
)
from contracts.perpx_v1_instrument import storage_longs, storage_shorts
from contracts.perpx_v1_exchange.structures import Parameter
from contracts.constants.perpx_constants import LIQUIDITY_PRECISION
from contracts.library.mathx6 import Mathx6
from contracts.library.vault import storage_liquidity
from contracts.library.position import Position, Info
from contracts.library.fees import Fees
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

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
        tempvar winnings = Mathx6.mul(price, info.size);
        let new_pnl = winnings - info.cost;

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
// @param mult The multiplication factor
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

// @notice Calculates the owner total exit fees
// @dev Internal function
// @param owner The owner of the positions
// @param instruments The instruments traded by owner
// @param mult The multiplication factor
// @return exit_fees The exit fees of the owner
func _calculate_exit_fees{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instruments: felt, mult: felt
) -> (exit_fees: felt) {
    alloc_locals;
    if (instruments == 0) {
        return (exit_fees=0);
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (position: Info) = Position.position(owner=owner, instrument=mult);
        let (price) = storage_oracles.read(mult);
        let (longs) = storage_longs.read(mult);
        let (shorts) = storage_shorts.read(mult);

        tempvar notional_longs = price * longs;
        tempvar notional_shorts = price * shorts;
        let (liquidity) = storage_liquidity.read(mult);
        let (new_fees) = Fees.compute_fees(
            price=price,
            amount=-position.size,
            long=notional_longs,
            short=notional_shorts,
            liquidity=liquidity,
        );
        let (f) = _calculate_exit_fees(owner=owner, instruments=q, mult=mult * 2);
        return (exit_fees=f + new_fees);
    }
    let (f) = _calculate_exit_fees(owner=owner, instruments=q, mult=mult * 2);
    return (exit_fees=f);
}

// @notice Calculates the owner margin requirements
// @dev Internal function
// @param owner The owner of the positions
// @param instruments The instruments traded by owner
// @param mult The multiplication factor
// @return margin_requirement The margin requirements of the owner
func _calculate_margin_requirement{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt, instruments: felt, mult
) -> (margin_requirement: felt) {
    alloc_locals;
    if (instruments == 0) {
        return (margin_requirement=0);
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (position: Info) = Position.position(owner=owner, instrument=mult);
        let (price) = storage_oracles.read(mult);
        let (parameters: Parameter) = storage_margin_parameters.read(mult);
        let (volatility) = storage_volatility.read(mult);

        let margin_limit = _calculate_margin_requirement_inner(
            size=position.size, price=price, k=parameters.k, volatility=volatility
        );
        let (m) = _calculate_margin_requirement(owner=owner, instruments=q, mult=mult * 2);
        return (margin_requirement=m + margin_limit);
    }
    let (m) = _calculate_margin_requirement(owner=owner, instruments=q, mult=mult * 2);
    return (margin_requirement=m);
}

// @notice Calculates the margin requirement
// @param size The size of the position
// @param price The price of the instrument
// @param parameters The k and lambda parameters used in margin calculation
// @param volatility The volatility of the instrument
// @return The margin requirement
func _calculate_margin_requirement_inner{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(size: felt, price: felt, k: felt, volatility: felt) -> felt {
    let sigma = Math64x61.sqrt(volatility);
    let temp = Math64x61.mul(k, sigma);
    let temp = Math64x61.exp(temp);
    let temp = Math64x61.sub(temp, Math64x61.ONE);
    let limit = Math64x61.div(Math64x61.ONE, 100 * Math64x61.ONE);
    let margin_factor = Math64x61.max(temp, limit);

    let price64x61 = Math64x61.fromFelt(price);
    let size64x61 = Math64x61.fromFelt(size);
    let price64x61 = Math64x61.div(price64x61, LIQUIDITY_PRECISION * Math64x61.ONE);
    let size64x61 = Math64x61.div(size64x61, LIQUIDITY_PRECISION * Math64x61.ONE);
    let size64x61 = abs_value(size64x61);

    let temp = Math64x61.mul(price64x61, size64x61);
    let temp = Math64x61.mul(temp, margin_factor);
    let margin_limit = _64x61_to_liquidity_precision(temp);
    return margin_limit;
}

// @notice Converts a felt using signed 64.61-bit fixed point
// @param length The length of the array
// @param instruments The instruments updated
func _64x61_to_liquidity_precision{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    x: felt
) -> felt {
    let (factor, _) = unsigned_div_rem(Math64x61.FRACT_PART, LIQUIDITY_PRECISION);
    let (y, _) = unsigned_div_rem(x, factor);
    return y;
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

// @notice Verify instruments value is lower than 2**instrument_count
// @param instruments The instruments updated
func _verify_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instruments: felt
) {
    alloc_locals;
    let (count) = storage_instrument_count.read();
    let (power) = pow(2, count);
    with_attr error_message("instruments limited to 2**instrument_count - 1") {
        [range_check_ptr] = instruments;
        assert [range_check_ptr + 1] = power - 1 - instruments;
    }
    let range_check_ptr = range_check_ptr + 2;
    return ();
}

// @notice Verify instrument is a power of 2 lower than 2**(instrument_count -1)
// @param instrument The instrument
func _verify_instrument{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) {
    alloc_locals;
    let (count) = storage_instrument_count.read();
    let (power) = pow(2, count - 1);
    with_attr error_message("instrument limited to 2**(instrument_count - 1)") {
        [range_check_ptr] = instrument;
        assert [range_check_ptr + 1] = power - instrument;
    }
    let range_check_ptr = range_check_ptr + 2;
    return _verify_instrument_loop(instrument=instrument);
}

// @notice Verify instrument is a power of 2 lower
// @param instrument The instrument
func _verify_instrument_loop{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instrument: felt
) {
    if (instrument == 1) {
        return ();
    }
    if (instrument == 0) {
        return ();
    }
    let (q, r) = unsigned_div_rem(instrument, 2);
    assert r = 0;
    return _verify_instrument(q);
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
        let (_) = Position.close_position(owner=owner, instrument=mult, price=0, fees=0);

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
// @param total The absolute total amount of liquidity to spread on instruments
// @param amount The amount to change the liquidity by
// @param instruments The instruments owned by the owner
// @param mult The multiplication factor
// @return The leftover margin
func _divide_margin{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    total: felt, amount: felt, instruments: felt, mult: felt
) -> felt {
    alloc_locals;
    if (instruments == 0) {
        return total;
    }
    let (q, r) = unsigned_div_rem(instruments, 2);
    if (r == 1) {
        let (liquidity) = storage_liquidity.read(mult);
        let is_negative = is_nn(liquidity + amount);
        if (is_negative == 0) {
            storage_liquidity.write(mult, 0);
            let t = _divide_margin(
                total=total - liquidity, amount=amount, instruments=q, mult=mult * 2
            );
            return t;
        }
        storage_liquidity.write(mult, liquidity + amount);
        let abs_amount = abs_value(amount);
        let t = _divide_margin(
            total=total - abs_amount, amount=amount, instruments=q, mult=mult * 2
        );
        return t;
    }
    let t = _divide_margin(total=total, amount=amount, instruments=q, mult=mult * 2);
    return t;
}
