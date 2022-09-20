%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.perpx_v1_exchange.permissionless import (
    add_liquidity,
    add_collateral,
    remove_liquidity,
)
from contracts.library.vault import storage_user_stake, storage_shares
from contracts.perpx_v1_exchange.storage import storage_token
from openzeppelin.token.erc20.library import ERC20, ERC20_allowances, ERC20_balances
from contracts.constants.perpx_constants import RANGE_CHECK_BOUND, LIMIT
from helpers.helpers import setup_helpers

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
    setup_helpers();
    let (local address) = get_contract_address();
    %{
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        context.self_address = ids.address 
        max_examples(200)
    %}

    return ();
}

@external
func test_add_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        if ids.amount > ids.RANGE_CHECK_BOUND:
            expect_revert(error_message="ERC20: amount is not a valid Uint256")
    %}
    ERC20.approve(spender=address, amount=Uint256(amount, 0));

    // add liquidity
    %{
        if ids.amount < 1 or ids.amount > ids.LIMIT:
            expect_revert(error_message="liquidity increase limited to 2**64")
    %}
    add_liquidity(amount=amount, instrument=INSTRUMENT);

    %{
        stop_prank_callable() 
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        account_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_stake[0] == ids.amount, f'user stake amount error, expected {ids.amount}, got {user_stake[0]}'
        assert user_stake[1] == ids.amount*100, f'user stake shares error, expected {ids.amount * 100}, got {user_stake[1]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.amount, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.amount}, 0] got {account_balance}'
        assert exchange_balance == [ids.amount, 0], f'exchange balance error, expected [{ids.amount}, 0] got {exchange_balance}'
    %}

    return ();
}

@external
func est_add_liquidity_limit{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT
    // prank the approval and the add liquidity calls
    %{ stop_prank_callable = start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT + 1, 0));
    // add liquidity
    add_liquidity(amount=LIMIT, instrument=INSTRUMENT);
    %{
        stop_prank_callable() 
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        account_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(context.self_address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_stake[0] == ids.LIMIT, f'user stake amount error, expected {ids.LIMIT}, got {user_stake[0]}'
        assert user_stake[1] == ids.LIMIT*100, f'user stake shares error, expected {ids.LIMIT * 100}, got {user_stake[1]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.LIMIT, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.LIMIT}, 0] got {account_balance}'
        assert exchange_balance == [ids.LIMIT, 0], f'exchange balance error, expected [{ids.LIMIT}, 0] got {exchange_balance}'
    %}
    %{ expect_revert(error_message="liquidity increase limited to 2**64") %}
    // add liquidity
    add_liquidity(amount=LIMIT + 1, instrument=INSTRUMENT);
    return ();
}

@external
func test_remove_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    provide_amount: felt, remove_amount: felt
) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        if ids.provide_amount > ids.RANGE_CHECK_BOUND:
            expect_revert(error_message="ERC20: amount is not a valid Uint256")
    %}
    ERC20.approve(spender=address, amount=Uint256(provide_amount, 0));

    // add liquidity
    %{
        if ids.provide_amount < 1 or ids.provide_amount > ids.LIMIT:
            expect_revert(error_message="liquidity increase limited to 2**64")
    %}
    add_liquidity(amount=provide_amount, instrument=INSTRUMENT);
    // remove the liquidity
    %{
        if ids.remove_amount < 1 or ids.remove_amount > ids.LIMIT:
            expect_revert(error_message="liquidity decrease limited to 2**64")
        elif ids.remove_amount > ids.provide_amount:
            expect_revert(error_message="insufficient balance")
    %}
    remove_liquidity(amount=remove_amount, instrument=INSTRUMENT);
    %{
        stop_prank_callable() 
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.INSTRUMENT])
        diff = ids.provide_amount - ids.remove_amount
        shares = 100*ids.provide_amount - 100*ids.remove_amount

        assert user_stake[0] == diff, f'user stake amount error, expected {diff}, got {user_stake[0]}'
        assert user_stake[1] == shares, f'user stake shares error, expected {shares}, got {user_stake[1]}'
    %}

    return ();
}

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
    // add liquidity
    add_liquidity(amount=LIMIT, instrument=INSTRUMENT);
    // remove the liquidity
    remove_liquidity(amount=LIMIT, instrument=INSTRUMENT);
    add_liquidity(amount=LIMIT, instrument=INSTRUMENT);
    %{ expect_revert(error_message="liquidity decrease limited to 2**64") %}
    // remove the liquidity
    remove_liquidity(amount=LIMIT + 1, instrument=INSTRUMENT);
    %{ stop_prank_callable() %}

    return ();
}

@external
func test_add_collateral{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    local address;
    %{ ids.address = context.self_address %}

    // prank the approval and the add liquidity calls
    %{
        stop_prank_callable = start_prank(ids.ACCOUNT)
        if ids.amount > ids.RANGE_CHECK_BOUND:
            expect_revert(error_message="ERC20: amount is not a valid Uint256")
    %}
    ERC20.approve(spender=address, amount=Uint256(amount, 0));
    %{
        if ids.amount < 1 or ids.amount > ids.LIMIT:
            expect_revert(error_message="collateral increase limited to 2**64")
    %}
    add_collateral(amount=amount);

    %{
        stop_prank_callable() 
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])
        account_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_collateral[0] == ids.amount, f'user collateral error, expected {ids.amount}, got {user_collateral[0]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.amount, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.amount}, 0] got {account_balance}'
        assert exchange_balance == [ids.amount, 0], f'exchange balance error, expected [{ids.amount}, 0] got {exchange_balance}'
    %}
    return ();
}

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
        stop_prank_callable() 
        user_collateral = load(ids.address, "storage_collateral", "felt", key=[ids.ACCOUNT])
        account_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(ids.address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_collateral[0] == ids.LIMIT, f'user collateral error, expected {ids.LIMIT}, got {user_collateral[0]}'
        assert account_balance == [ids.RANGE_CHECK_BOUND-1-ids.LIMIT, 0], f'account balance error, expected [{ids.RANGE_CHECK_BOUND-1-ids.LIMIT}, 0] got {account_balance}'
        assert exchange_balance == [ids.LIMIT, 0], f'exchange balance error, expected [{ids.LIMIT}, 0] got {exchange_balance}'
    %}
    return ();
}
