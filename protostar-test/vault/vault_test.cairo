%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Vault, Stake

//
// Constants
//

const INITIAL_SHARES = 2 ** 50;
const INITIAL_USER_SHARES = 2 ** 30;
const INITIAL_LIQUIDITY = 2 ** 60;
const INITIAL_USER_LIQUIDITY = 2 ** 40;

const OWNER = 1;
const INSTRUMENT = 1;

const LIQUIDITY_INCREASE = 2 ** 10;

//
// Interface
//

@contract_interface
namespace TestContract {
    func provide_liquidity_test(amount: felt, owner: felt, instrument: felt) -> () {
    }
    func withdraw_liquidity_test(amount: felt, owner: felt, instrument: felt) -> () {
    }
}

//
// Setup
//

@external
func __setup__() {
    alloc_locals;
    local address;
    %{
        max_examples(200)
        context.contract_address = deploy_contract("./contracts/test/vault_test.cairo").contract_address 
        ids.address = context.contract_address
        store(context.contract_address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])

        store(context.contract_address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(context.contract_address, "storage_user_stake", [ids.INITIAL_USER_LIQUIDITY, ids.INITIAL_USER_SHARES, 0], key=[ids.OWNER, ids.INSTRUMENT])
    %}

    return ();
}

//
// Tests
//

@external
func test_provide_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    rand: felt
) {
    alloc_locals;
    local amount;
    local address;
    %{
        ids.address = context.contract_address
        assume(ids.rand != 0)
        ids.amount = ids.rand % (2**64)
    %}
    // retrieve liquidity, shares and user_shares
    %{
        pre_liquidity = load(ids.address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        pre_shares = load(ids.address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
    %}

    // provide test liquidity
    TestContract.provide_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        if pre_liquidity == 0:
            inc = ids.amount * 100
        else:
            inc = ids.amount * pre_shares // pre_liquidity

        shares = load(ids.address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
        assert (pre_shares + inc) == shares, f'shares: {pre_shares + inc} different from {shares}'
        assert (stake[0] + ids.amount) == user_stake[0], f'user_amount: {stake[0] + ids.amount} different from {user_stake[0]}'
        assert (stake[1] + inc) == user_stake[1], f'user_shares: {stake[1] + inc} different from {user_stake[1]}'
    %}

    return ();
}

@external
func test_withdraw_liquidity_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // provide then try to retrieve more
    %{ expect_revert(error_message="insufficient balance") %}
    Vault.provide_liquidity(amount=100, owner=0, instrument=1);
    Vault.withdraw_liquidity(amount=101, owner=0, instrument=1);

    // should withdraw
    Vault.withdraw_liquidity(amount=100, owner=0, instrument=1);
    %{
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
        assert user_stake[0] == 0, f'user_amount: expected 0'
        assert user_stake[1] == 0, f'user_shares: expected 0'
    %}

    return ();
}

@external
func test_withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    rand: felt
) {
    alloc_locals;
    local amount;
    local address;
    local rand = rand;
    %{
        ids.address = context.contract_address
        assume(ids.rand != 0)
        amount = ids.rand%ids.INITIAL_USER_LIQUIDITY
        ids.amount = amount + 1
    %}
    TestContract.provide_liquidity_test(
        contract_address=address, amount=LIQUIDITY_INCREASE, owner=OWNER, instrument=INSTRUMENT
    );
    // retrieve liquidity, shares and user_shares
    %{
        pre_liquidity = load(ids.address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        pre_shares = load(ids.address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
    %}

    TestContract.withdraw_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        shares = load(ids.address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        share_dec = ids.amount * pre_shares // pre_liquidity
        user_share_dec = ids.amount * stake[1] // stake[0]
        assert (pre_shares - share_dec) == shares,  f'shares: {pre_shares - share_dec} different from {shares}'
        assert (stake[0] - ids.amount) == user_stake[0],  f'user_amount: {stake[0] - ids.amount} different from {user_stake[0]}'
        assert (stake[1] - user_share_dec) == user_stake[1],  f'user_shares: {stake[1] - user_share_dec} different from {user_stake[1]}'
    %}
    return ();
}
