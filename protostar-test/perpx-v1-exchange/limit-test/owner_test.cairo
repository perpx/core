%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.constants.perpx_constants import (
    LIMIT,
    RANGE_CHECK_BOUND,
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
)
from contracts.perpx_v1_exchange.owners import (
    update_prices,
    update_margin_parameters,
    flush_queue,
    update_prev_prices,
    _update_volatility,
    _remove_collateral,
)
from contracts.perpx_v1_exchange.permissionless import add_collateral
from contracts.perpx_v1_exchange.structures import Parameter
from src.openzeppelin.token.erc20.library import ERC20
from openzeppelin.access.ownable.library import Ownable_owner
from lib.cairo_math_64x61_git.contracts.cairo_math_64x61.math64x61 import Math64x61

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const MATH_PRECISION = 2 ** 64 + 2 ** 61;
const MATH64X61_FRACT_PART = 2 ** 61;

//
// Helper
//

@external
func transferFrom{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}
    let caller = address;
    // subtract allowance
    ERC20._spend_allowance(sender, caller, amount);
    // execute transfer
    ERC20._transfer(sender, recipient, amount);
    return ();
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    let (sender) = get_caller_address();
    ERC20._transfer(sender, recipient, amount);
    return ();
}

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    let (local address) = get_contract_address();
    Ownable_owner.write(OWNER);
    %{
        context.self_address = ids.address
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        max_examples(200)
    %}
    return ();
}

// TEST FLUSH QUEUE
@external
func test_flush_queue_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    flush_queue();
    return ();
}

// TEST UPDATE PREV PRICES

@external
func test_update_prev_prices_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    // test case: wrong owner
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
    // test case: wrong owner
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
    // test case: wrong owner
    alloc_locals;
    let (local arr: Parameter*) = alloc();
    %{
        start_prank(1)
        expect_revert(error_message="Ownable: caller is not the owner")
    %}
    update_margin_parameters(parameters_len=0, parameters=arr, instruments=0);
    return ();
}
