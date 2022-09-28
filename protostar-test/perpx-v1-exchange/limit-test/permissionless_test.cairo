%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.perpx_v1_exchange.permissionless import (
    add_liquidity,
    remove_liquidity,
    add_collateral,
    remove_collateral,
)
from src.openzeppelin.token.erc20.library import ERC20
from contracts.constants.perpx_constants import RANGE_CHECK_BOUND, LIMIT

//
// Constants
//

const OWNER = 12345;
const ACCOUNT = 123;
const INSTRUMENT_COUNT = 10;
const INSTRUMENT = 1;

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
    %{
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        context.self_address = ids.address
    %}

    return ();
}

// TEST ADD LIQUIDITY

@external
func test_add_liquidity_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT
    // prank the approval and the add liquidity calls
    %{ start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT + 1, 0));

    %{ expect_revert(error_message=f'liquidity increase limited to {ids.LIMIT}') %}
    add_liquidity(amount=LIMIT + 1, instrument=INSTRUMENT);
    return ();
}

// TEST REMOVE LIQUIDITY

@external
func test_remove_liquidity_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT
    // prank the approval and the add liquidity calls
    %{ stop_prank_callable = start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT, 0));
    add_liquidity(amount=LIMIT, instrument=INSTRUMENT);

    // remove the liquidity
    remove_liquidity(amount=LIMIT, instrument=INSTRUMENT);
    add_liquidity(amount=LIMIT, instrument=INSTRUMENT);

    // test case: amount = 0
    // remove the liquidity
    %{ expect_revert(error_message=f'liquidity decrease limited to {ids.LIMIT}') %}
    remove_liquidity(amount=0, instrument=INSTRUMENT);

    return ();
}

// TEST ADD COLLATERAL

@external
func test_add_collateral_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT
    // prank the approval and the add liquidity calls
    %{ stop_prank_callable = start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=address, amount=Uint256(LIMIT, 0));
    add_collateral(amount=LIMIT);

    %{
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])
        account_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_collateral[0] == ids.LIMIT, f'user collateral error, expected {ids.LIMIT}, got {user_collateral[0]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.LIMIT, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.LIMIT}, 0] got {account_balance}'
        assert exchange_balance == [ids.LIMIT, 0], f'exchange balance error, expected [{ids.LIMIT}, 0] got {exchange_balance}'
    %}

    // test case: amount = 0
    // add the collateral
    %{ expect_revert(error_message=f'collateral increase limited to {ids.LIMIT}') %}
    add_collateral(amount=0);
    return ();
}

// TEST REMOVE COLLATERAL

@external
func test_remove_collateral_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT
    // prank the approval and the add liquidity calls
    %{ stop_prank_callable = start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=address, amount=Uint256(LIMIT, 0));
    add_collateral(amount=LIMIT);
    remove_collateral(amount=LIMIT);

    // test case: amount = 0
    // remove the collateral
    %{ expect_revert(error_message=f'collateral decrease limited to {ids.LIMIT}') %}
    remove_collateral(amount=0);
    return ();
}
