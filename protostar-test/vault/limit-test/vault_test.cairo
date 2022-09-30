%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.constants.perpx_constants import LIMIT
from contracts.library.vault import Vault, Stake

//
// Constants
//

const OWNER = 1;
const INSTRUMENT = 1;

//
// Setup
//

@external
func __setup__() {
    return ();
}

// TEST PROVIDE LIQUIDITY

@external
func test_provide_liquidity_revert_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    local amount;
    // test case: amount = LIMIT/100 + 1
    %{
        ids.amount = ids.LIMIT // 100 + 1
        expect_revert(error_message=f'shares limited to {ids.LIMIT}')
    %}
    Vault.provide_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);
    return ();
}

@external
func test_provide_liquidity_revert_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // test case: amount_1 = 1, amount_2 = ids.LIMIT//100
    local amount_1 = 1;
    local amount_2;
    Vault.provide_liquidity(amount=amount_1, owner=OWNER, instrument=INSTRUMENT);
    %{
        ids.amount_2 = ids.LIMIT // 100
        expect_revert(error_message=f'shares limited to {ids.LIMIT}')
    %}
    Vault.provide_liquidity(amount=amount_2, owner=OWNER, instrument=INSTRUMENT);
    return ();
}

@external
func test_provide_liquidity_passing_1{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    local amount;
    // test case: amount = LIMIT/100
    %{ ids.amount = ids.LIMIT // 100 %}
    Vault.provide_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);
    return ();
}

@external
func test_provide_liquidity_passing_2{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // test case: amount_1 = 1, amount_2 = ids.LIMIT//100 - 1
    local amount_1 = 1;
    local amount_2;
    Vault.provide_liquidity(amount=amount_1, owner=OWNER, instrument=INSTRUMENT);
    %{ ids.amount_2 = ids.LIMIT // 100 - 1 %}
    Vault.provide_liquidity(amount=amount_2, owner=OWNER, instrument=INSTRUMENT);
    return ();
}

// TEST WITHDRAW LIQUIDITY

@external
func test_withdraw_liquidity_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // provide then try to retrieve more
    Vault.provide_liquidity(amount=100, owner=OWNER, instrument=INSTRUMENT);
    %{ expect_revert(error_message="insufficient balance") %}
    Vault.withdraw_liquidity(amount=101, owner=OWNER, instrument=INSTRUMENT);
    return ();
}
