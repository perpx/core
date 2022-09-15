%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.pow import pow

from contracts.perpx_v1_exchange.storage import storage_oracles, storage_instrument_count
from contracts.perpx_v1_instrument import storage_longs, storage_shorts
from contracts.library.vault import storage_liquidity
from contracts.library.position import Position, Info
from contracts.library.fees import Fees

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

// TODO: test
func _verify_instruments{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    instruments: felt
) {
    alloc_locals;
    let (count) = storage_instrument_count.read();
    let (power) = pow(2, count);
    with_attr error_message("instruments limited to 2**instrument_count") {
        [range_check_ptr] = instruments;
        assert [range_check_ptr + 1] = power - 1 - instruments;
    }
    let range_check_ptr = range_check_ptr + 2;
    return ();
}
