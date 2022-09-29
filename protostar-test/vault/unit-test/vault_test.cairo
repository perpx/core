%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.constants.perpx_constants import LIMIT
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
// Setup
//

@external
func __setup__{syscall_ptr: felt*}() {
    alloc_locals;
    let (address) = get_contract_address();
    %{
        max_examples(200)
        context.self_address = ids.address
        store(ids.address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])
        store(ids.address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(ids.address, "storage_user_stake", [ids.INITIAL_USER_LIQUIDITY, ids.INITIAL_USER_SHARES, 0], key=[ids.OWNER, ids.INSTRUMENT])
    %}

    return ();
}

// TEST PROVIDE LIQUIDITY

@external
func test_provide_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local amount;
    %{ ids.amount = ids.random % ids.LIMIT + 1 %}
    // retrieve liquidity, shares and user_shares
    %{
        pre_liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        pre_shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
    %}

    // provide test liquidity
    Vault.provide_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);
    %{
        if pre_liquidity == 0:
            inc = ids.amount * 100
        else:
            inc = ids.amount * pre_shares // pre_liquidity

        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
        assert (pre_shares + inc) == shares, f'shares: {pre_shares + inc} different from {shares}'
        assert (stake[0] + ids.amount) == user_stake[0], f'user_amount: {stake[0] + ids.amount} different from {user_stake[0]}'
        assert (stake[1] + inc) == user_stake[1], f'user_shares: {stake[1] + inc} different from {user_stake[1]}'
    %}

    return ();
}

// TEST WITHDRAW LIQUIDITY

@external
func test_withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local amount;
    %{ ids.amount = ids.random % ids.INITIAL_USER_LIQUIDITY + 1 %}
    Vault.provide_liquidity(amount=LIQUIDITY_INCREASE, owner=OWNER, instrument=INSTRUMENT);
    // retrieve liquidity, shares and user_shares
    %{
        pre_liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        pre_shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
    %}

    Vault.withdraw_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    %{
        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        share_dec = ids.amount * pre_shares // pre_liquidity
        user_share_dec = ids.amount * stake[1] // stake[0]
        assert (pre_shares - share_dec) == shares,  f'shares: {pre_shares - share_dec} different from {shares}'
        assert (stake[0] - ids.amount) == user_stake[0],  f'user_amount: {stake[0] - ids.amount} different from {user_stake[0]}'
        assert (stake[1] - user_share_dec) == user_stake[1],  f'user_shares: {stake[1] - user_share_dec} different from {user_stake[1]}'
    %}
    return ();
}
