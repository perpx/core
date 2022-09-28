%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_contract_address

from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND, LIQUIDITY_PRECISION
from contracts.perpx_v1_exchange.owners import (
    update_prev_prices,
    _update_volatility,
    update_prices,
    update_margin_parameters,
)
from contracts.perpx_v1_exchange.structures import Parameter
from openzeppelin.access.ownable.library import Ownable_owner
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const INSTRUMENT_COUNT = 10;
const MATH_PRECISION = 2 ** 64 + 2 ** 61;

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    Ownable_owner.write(OWNER);
    return ();
}

// TEST UPDATE PREV PRICES

@external
func test_update_prev_prices_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    let (local arr: felt*) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_prev_prices(prev_prices_len=0, prev_prices=arr);
    return ();
}

// TEST UPDATE PRICES

@external
func test_update_prices_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local arr) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_prices(prices_len=0, prices=arr, instruments=0);
    return ();
}

// TEST UPDATE MARGIN PARAMETERS

@external
func test_update_margin_parameters_limit{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let (local arr: Parameter*) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_margin_parameters(parameters_len=0, parameters=arr, instruments=0);
    return ();
}
