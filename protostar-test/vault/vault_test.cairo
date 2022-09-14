%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Vault, Stake
from contracts.test.vault_test import provide_liquidity_test, view_shares, view_user_stake

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
    func view_shares(instrument: felt) -> (shares: felt) {
    }
    func view_user_stake(owner: felt, instrument: felt) -> (stake: Stake) {
    }
    func view_liquidity(instrument: felt) -> (liquidity: felt) {
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
        context.contract_address = deploy_contract("./contracts/test/vault_test.cairo").contract_address 
        ids.address = context.contract_address
        store(context.contract_address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])

        store(context.contract_address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(context.contract_address, "storage_user_stake", [ids.INITIAL_USER_LIQUIDITY, ids.INITIAL_USER_SHARES], key=[ids.OWNER, ids.INSTRUMENT])
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
    local rand = rand;
    local address;
    %{
        ids.address = context.contract_address
        assume(ids.rand != 0)
        ids.amount = ids.rand % (2**64)
    %}
    // retrieve liquidity, shares and user_shares
    let (local pre_liquidity) = TestContract.view_liquidity(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local pre_shares) = TestContract.view_shares(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local pre_user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    // provide test liquidity
    TestContract.provide_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    // get shares and user_shares
    let (local shares) = TestContract.view_shares(contract_address=address, instrument=INSTRUMENT);
    let (local user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        if ids.pre_liquidity == 0:
            inc = ids.amount * 100
        else:
            inc = ids.amount * ids.pre_shares // ids.pre_liquidity
        assert (ids.pre_shares + inc) == ids.shares, f'shares: {ids.pre_shares + inc} different from {ids.shares}'
        assert (ids.pre_user_stake.shares + inc) == ids.user_stake.shares, f'user_shares: {ids.pre_user_stake.shares + inc} different from {ids.user_stake.shares}'
        assert (ids.pre_user_stake.amount + ids.amount) == ids.user_stake.amount, f'user_amount: {ids.pre_user_stake.amount + inc} different from {ids.user_stake.amount}'
    %}

    return ();
}

@external
func test_withdraw_liquidity_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // try to withdraw with null amount
    %{ expect_revert(error_message="null amount") %}
    Vault.withdraw_liquidity(amount=0, owner=0, instrument=1);

    // provide then try to retrieve more
    %{ expect_revert(error_message="insufficient balance") %}
    Vault.provide_liquidity(amount=100, owner=0, instrument=1);
    Vault.withdraw_liquidity(amount=101, owner=0, instrument=1);

    // should withdraw
    Vault.withdraw_liquidity(amount=100, owner=0, instrument=1);
    let (local user_stake: Stake) = Vault.view_user_stake(owner=OWNER, instrument=INSTRUMENT);
    %{
        assert user_stake.amount == 0, f'user_amount: expected 0'
        assert user_stake.shares == 0, f'user_shares: expected 0'
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
    // withdraw liquidity, shares and user_shares
    let (local pre_liquidity) = TestContract.view_liquidity(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local pre_shares) = TestContract.view_shares(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local pre_user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    TestContract.withdraw_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    let (local shares) = TestContract.view_shares(contract_address=address, instrument=INSTRUMENT);
    let (local user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        share_dec = ids.amount * ids.pre_shares // ids.pre_liquidity
        user_share_dec = ids.amount * ids.pre_user_stake.shares // ids.pre_user_stake.amount
        assert (ids.pre_shares - share_dec) == ids.shares,  f'shares: {ids.pre_shares + share_dec} different from {ids.shares}'
        assert (ids.pre_user_stake.shares - user_share_dec) == ids.user_stake.shares,  f'user_shares: {ids.pre_user_stake.shares - user_share_dec} different from {ids.user_stake.shares}'
        assert (ids.pre_user_stake.amount - ids.amount) == ids.user_stake.amount,  f'user_amount: {ids.pre_user_stake.amount - amount} different from {ids.user_stake.amount}'
    %}
    return ();
}
