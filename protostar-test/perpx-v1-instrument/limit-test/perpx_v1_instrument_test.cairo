%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Stake
from contracts.perpx_v1_instrument import update_liquidity, update_long_short
from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const INITIAL_SHARES = 2 ** 50;
const INITIAL_USER_SHARES = 2 ** 30;
const INITIAL_LIQUIDITY = 2 ** 60;
const INITIAL_USER_LIQUIDITY = 2 ** 40;

const INITIAL_LONGS = 2 ** 19;
const INITIAL_SHORTS = 2 ** 21 + 1;
const PRICE = 10 ** 8;

const OWNER = 1;
const INSTRUMENT = 1;

//
// Setup
//

@external
func __setup__() {
    return ();
}

// TEST UPDATE LONGS

@external
func test_update_longs_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=0
    update_long_short(amount=0, instrument=INSTRUMENT, is_long=1);
    // test case: amount=RANGE_CHECK_BOUND - 1
    update_long_short(amount=RANGE_CHECK_BOUND - 1, instrument=INSTRUMENT, is_long=1);
    return ();
}

@external
func test_update_longs_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=-1
    local amount = -1;
    %{ expect_revert(error_message="negative longs") %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=1);
    return ();
}

@external
func test_update_longs_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=RANGE_CHECK_BOUND
    local amount = RANGE_CHECK_BOUND;
    %{ expect_revert(error_message="negative longs") %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=1);
    return ();
}

// TEST UPDATE SHORTS

@external
func test_update_shorts_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=0
    update_long_short(amount=0, instrument=INSTRUMENT, is_long=0);
    // test case: amount=RANGE_CHECK_BOUND - 1
    update_long_short(amount=RANGE_CHECK_BOUND - 1, instrument=INSTRUMENT, is_long=0);
    return ();
}

@external
func test_update_shorts_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=-1
    local amount = -1;
    %{ expect_revert(error_message="negative shorts") %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=0);
    return ();
}

@external
func test_update_shorts_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    // test case: amount=RANGE_CHECK_BOUND
    local amount = RANGE_CHECK_BOUND;
    %{ expect_revert(error_message="negative shorts") %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=0);
    return ();
}
