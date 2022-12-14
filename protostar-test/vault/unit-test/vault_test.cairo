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
        import importlib  
        utils = importlib.import_module("protostar-test.utils")
        context.self_address = ids.address
        store(ids.address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])
        store(ids.address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(ids.address, "storage_user_stake", [ids.INITIAL_USER_LIQUIDITY, ids.INITIAL_USER_SHARES, 0], key=[ids.OWNER, ids.INSTRUMENT])
        max_examples(utils.read_max_examples("./config.yml"))
    %}

    return ();
}

// TEST PROVIDE LIQUIDITY

@external
func setup_provide_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(amount=strategy.integers(1, ids.LIMIT//100)) %}
    return ();
}

@external
func test_provide_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
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
        assert (stake[0] + inc) == user_stake[0], f'user_shares: {stake[0] + inc} different from {user_stake[0]}'
    %}

    return ();
}

// TEST WITHDRAW LIQUIDITY

@external
func setup_withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(amount=strategy.integers(1, ids.INITIAL_USER_LIQUIDITY)) %}
    return ();
}

@external
func test_withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    Vault.provide_liquidity(amount=LIQUIDITY_INCREASE, owner=OWNER, instrument=INSTRUMENT);
    // retrieve liquidity, shares and user_shares
    %{
        #modify the liquidity
        liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0] + ids.amount
        store(context.self_address, "storage_liquidity", [liquidity], key=[ids.INSTRUMENT])
        pre_shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])
    %}

    Vault.withdraw_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    %{
        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        share_dec = ids.amount * pre_shares // liquidity
        assert (pre_shares - share_dec) == shares,  f'shares: {pre_shares - share_dec} different from {shares}'
        assert (stake[0] - share_dec) == user_stake[0],  f'user_shares: {stake[0] - share_dec} different from {user_stake[0]}'
    %}
    return ();
}
