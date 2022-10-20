%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_contract_address, get_caller_address

from contracts.perpx_v1_exchange.permissionless import (
    trade,
    close,
    add_liquidity,
    remove_liquidity,
    add_collateral,
    remove_collateral,
)
from contracts.constants.perpx_constants import (
    LIQUIDITY_PRECISION,
    VOLATILITY_FEE_RATE_PRECISION,
    MIN_LIQUIDITY,
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
    %{
        store(ids.address, "ERC20_balances", [ids.RANGE_CHECK_BOUND - 1, 0], key=[ids.ACCOUNT])
        store(ids.address, "storage_token", [ids.address])
        store(ids.address, "storage_instrument_count", [ids.INSTRUMENT_COUNT])
        store(ids.address, "storage_queue_limit", [100])
        context.self_address = ids.address
    %}

    return ();
}

// TEST ADD LIQUIDITY

@external
func test_add_liquidity_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    local amount;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT//100 + 1
    // prank the approval and the add liquidity calls
    %{
        ids.amount = ids.LIMIT//100+1
        start_prank(ids.ACCOUNT)
    %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT + 1, 0));

    %{ expect_revert(error_message=f'shares limited to {ids.LIMIT}') %}
    add_liquidity(amount=amount, instrument=INSTRUMENT);
    return ();
}

@external
func test_add_liquidity_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local instrument;
    local address;
    %{
        ids.instrument = 2**(ids.INSTRUMENT_COUNT - 1) + 1 
        ids.address = context.self_address
    %}

    // test case: incorrect instrument
    // prank the approval and the add liquidity calls
    %{ start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=ACCOUNT, amount=Uint256(2 * LIMIT + 1, 0));

    %{ expect_revert(error_message="instrument limited to 2**(instrument_count - 1)") %}
    add_liquidity(amount=1, instrument=instrument);
    return ();
}

// TEST REMOVE LIQUIDITY

@external
func test_remove_liquidity_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    local address;
    local amount;
    %{ ids.address = context.self_address %}

    // test case: amount = LIMIT//100
    // prank the approval and the add liquidity calls
    %{
        ids.amount = ids.LIMIT//100
        stop_prank_callable = start_prank(ids.ACCOUNT)
    %}
    ERC20.approve(spender=address, amount=Uint256(2 * LIMIT, 0));
    add_liquidity(amount=amount, instrument=INSTRUMENT);

    // remove the liquidity
    remove_liquidity(amount=amount, instrument=INSTRUMENT);
    add_liquidity(amount=amount, instrument=INSTRUMENT);

    // test case: amount = 0
    // remove the liquidity
    %{ expect_revert(error_message=f'liquidity decrease limited to {ids.LIMIT}') %}
    remove_liquidity(amount=0, instrument=INSTRUMENT);

    return ();
}

@external
func test_remove_liquidity_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    ) {
    alloc_locals;
    local instrument;
    local address;
    %{
        ids.instrument = 2**(ids.INSTRUMENT_COUNT - 1) + 1 
        ids.address = context.self_address
    %}

    // test case: incorrect instrument
    // prank the approval and the add liquidity calls
    %{ start_prank(ids.ACCOUNT) %}
    ERC20.approve(spender=ACCOUNT, amount=Uint256(2 * LIMIT + 1, 0));

    %{ expect_revert(error_message="instrument limited to 2**(instrument_count - 1)") %}
    remove_liquidity(amount=1, instrument=instrument);
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

@external
func test_trade_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: caller = 0
    %{
        start_prank(0) 
        expect_revert(error_message=f'caller is the zero address')
    %}
    trade(amount=1, instrument=1, valid_until=1);
    return ();
}

@external
func test_trade_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: amount = 0
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'trading amount limited to {ids.LIMIT}')
    %}
    trade(amount=0, instrument=1, valid_until=1);
    return ();
}

@external
func test_trade_limit_3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: amount = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'trading amount limited to {ids.LIMIT}')
    %}
    trade(amount=LIMIT + 1, instrument=1, valid_until=1);
    return ();
}

@external
func test_trade_limit_4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: amount = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_positions", [0, 0, ids.LIMIT], key=[ids.ACCOUNT, 1])
        expect_revert(error_message=f'total position size limited to {ids.LIMIT}')
    %}
    trade(amount=1, instrument=1, valid_until=1);
    return ();
}

@external
func test_trade_limit_5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: valid_until = 0
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    trade(amount=1, instrument=1, valid_until=0);
    return ();
}

@external
func test_trade_limit_6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: valid_until = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    trade(amount=1, instrument=1, valid_until=LIMIT + 1);
    return ();
}

@external
func test_trade_limit_7{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: storage_operations_count = storage_queue_limit
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_operations_count", [100])
        expect_revert(error_message=f'queue size limit reached')
    %}
    trade(amount=1, instrument=1, valid_until=1);
    return ();
}

@external
func test_trade_limit_8{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: incorrect instrument
    alloc_locals;
    local instrument;
    %{
        ids.instrument = 2**(ids.INSTRUMENT_COUNT) + 1 
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message="instrument limited to 2**(instrument_count - 1)")
    %}
    trade(amount=1, instrument=instrument, valid_until=1);
    return ();
}

@external
func test_trade_limit_9{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: insufficient liquidity
    alloc_locals;
    local instrument;
    %{
        ids.instrument = 1
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_liquidity", [ids.MIN_LIQUIDITY - 1], key=[ids.instrument])
        expect_revert(error_message=f'minimal liquidity not reached {ids.MIN_LIQUIDITY}')
    %}
    trade(amount=1, instrument=instrument, valid_until=1);
    return ();
}

@external
func test_close_limit_1{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: caller = 0
    %{
        start_prank(0) 
        expect_revert(error_message=f'caller is the zero address')
    %}
    close(instrument=1, valid_until=1);
    return ();
}

@external
func test_close_limit_2{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: valid_until = 0
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    close(instrument=1, valid_until=0);
    return ();
}

@external
func test_close_limit_3{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: valid_until = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    close(instrument=1, valid_until=LIMIT + 1);
    return ();
}

@external
func test_close_limit_4{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: storage_operations_count = storage_queue_limit
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_operations_count", [100])
        expect_revert(error_message=f'queue size limit reached')
    %}
    close(instrument=1, valid_until=1);
    return ();
}

@external
func test_close_limit_5{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: incorrect instrument
    alloc_locals;
    local instrument;
    %{
        ids.instrument = 2**(ids.INSTRUMENT_COUNT) + 1 
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message="instrument limited to 2**(instrument_count - 1)")
    %}
    close(instrument=instrument, valid_until=1);
    return ();
}

@external
func test_close_limit_6{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // test case: insufficient liquidity
    alloc_locals;
    local instrument;
    %{
        ids.instrument = 1
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_liquidity", [ids.MIN_LIQUIDITY - 1], key=[ids.instrument])
        expect_revert(error_message=f'minimal liquidity not reached {ids.MIN_LIQUIDITY}')
    %}
    close(instrument=instrument, valid_until=1);
    return ();
}

@external
func test_remove_collateral_limit_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: caller = 0
    %{
        start_prank(0) 
        expect_revert(error_message=f'caller is the zero address')
    %}
    remove_collateral(amount=1, valid_until=1);
    return ();
}

@external
func test_remove_collateral_limit_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: amount = 0
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'collateral decrease limited to {ids.LIMIT}')
    %}
    remove_collateral(amount=0, valid_until=1);
    return ();
}

@external
func test_remove_collateral_limit_3{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: amount = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        expect_revert(error_message=f'collateral decrease limited to {ids.LIMIT}')
    %}
    remove_collateral(amount=LIMIT + 1, valid_until=1);
    return ();
}

@external
func test_remove_collateral_limit_4{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: valid_until = 0
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_user_instruments", [10], key=[ids.ACCOUNT])
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    remove_collateral(amount=1, valid_until=0);
    return ();
}

@external
func test_remove_collateral_limit_5{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: valid_until = LIMIT + 1
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_user_instruments", [10], key=[ids.ACCOUNT])
        expect_revert(error_message=f'invalid expiration timestamp')
    %}
    remove_collateral(amount=1, valid_until=LIMIT + 1);
    return ();
}

@external
func test_remove_collateral_limit_6{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    // test case: storage_operations_count = storage_queue_limit
    %{
        start_prank(ids.ACCOUNT) 
        store(context.self_address, "storage_operations_count", [100])
        store(context.self_address, "storage_user_instruments", [10], key=[ids.ACCOUNT])
        expect_revert(error_message=f'queue size limit reached')
    %}
    remove_collateral(amount=1, valid_until=1);
    return ();
}
