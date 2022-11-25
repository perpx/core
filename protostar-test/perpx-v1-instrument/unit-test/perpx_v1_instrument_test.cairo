%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_contract_address

from contracts.library.vault import Stake
from contracts.perpx_v1_instrument import update_liquidity, update_long_short
from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const INITIAL_SHARES = 2 ** 50;
const INITIAL_USER_SHARES = 2 ** 30;
const INITIAL_LIQUIDITY = 2 ** 60;
const INITIAL_USER_LIQUIDITY = 2 ** 40;

const INITIAL_LONGS = 2 ** 19;
const INITIAL_SHORTS = 2 ** 21 + 1;
const PRICE = 10 ** 8;

const OWNER = 1;
const INSTRUMENT = 1;

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
        context.signed_int = utils.signed_int
        context.self_address = ids.address
        store(ids.address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])
        store(ids.address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(ids.address, "storage_user_stake", [ids.INITIAL_USER_SHARES, 0], key=[ids.OWNER, ids.INSTRUMENT])
        store(ids.address, "storage_longs", [ids.INITIAL_LONGS], key=[ids.INSTRUMENT])
        store(ids.address, "storage_shorts", [ids.INITIAL_SHORTS], key=[ids.INSTRUMENT])
        max_examples(utils.read_max_examples("./config.yml"))
    %}
    return ();
}

// TEST UPDATE LIQUIDITY

@external
func test_update_liquidity_negative{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let amount = PRIME - 2 ** 20;

    update_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    %{
        liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        amount = context.signed_int(ids.amount)
        share_dec = amount * ids.INITIAL_SHARES // ids.INITIAL_LIQUIDITY

        assert(ids.INITIAL_LIQUIDITY + amount == liquidity), f'liquidity error: {ids.INITIAL_LIQUIDITY + amount} different from {liquidity}'
        assert(ids.INITIAL_SHARES + share_dec == shares), f'shares error: {ids.INITIAL_SHARES + share_dec} different from {shares}'
        assert(ids.INITIAL_USER_SHARES + share_dec == user_stake[0]), f'user_shares error: {ids.INITIAL_USER_SHARES + share_dec} different from {user_stake[0]}'
    %}
    return ();
}

@external
func test_update_liquidity_positive{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let amount = 2 ** 30;

    update_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    %{
        liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        amount = context.signed_int(ids.amount)
        share_inc = amount * ids.INITIAL_SHARES // ids.INITIAL_LIQUIDITY

        assert(ids.INITIAL_LIQUIDITY + amount == liquidity), f'liquidity error: {ids.INITIAL_LIQUIDITY + amount} different from {liquidity}'
        assert(ids.INITIAL_SHARES + share_inc == shares), f'shares error: {ids.INITIAL_SHARES + share_inc} different from {shares}'
        assert(ids.INITIAL_USER_SHARES + share_inc == user_stake[0]), f'user_shares error: {ids.INITIAL_USER_SHARES + share_inc} different from {user_stake[0]}'
    %}
    return ();
}

@external
func setup_update_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(amount=strategy.integers(-ids.INITIAL_USER_LIQUIDITY, ids.LIMIT//100).filter(lambda x: x != 0)) %}
    return ();
}

@external
func test_update_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    update_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    %{
        import math
        liquidity = load(context.self_address, "storage_liquidity", "felt", key=[ids.INSTRUMENT])[0]
        shares = load(context.self_address, "storage_shares", "felt", key=[ids.INSTRUMENT])[0]
        user_stake = load(context.self_address, "storage_user_stake", "Stake", key=[ids.OWNER, ids.INSTRUMENT])

        amount = context.signed_int(ids.amount)
        share_inc = amount * ids.INITIAL_SHARES
        share_inc = share_inc // ids.INITIAL_LIQUIDITY if share_inc > 0 else math.ceil(share_inc/ids.INITIAL_LIQUIDITY)

        assert(ids.INITIAL_LIQUIDITY + amount == liquidity), f'liquidity error: {ids.INITIAL_LIQUIDITY + amount} different from {liquidity}'
        assert(ids.INITIAL_SHARES + share_inc == shares), f'shares error: {ids.INITIAL_SHARES + share_inc} different from {shares}'
        assert(ids.INITIAL_USER_SHARES + share_inc == user_stake[0]), f'user_shares error: {ids.INITIAL_USER_SHARES + share_inc} different from {user_stake[0]}'
    %}
    return ();
}

// TEST UPDATE LONGS

@external
func setup_update_longs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(amount=strategy.integers(-ids.INITIAL_LONGS, ids.RANGE_CHECK_BOUND - ids.INITIAL_LONGS).filter(lambda x: x != 0)) %}
    return ();
}

@external
func test_update_longs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=1);

    %{
        longs = load(context.self_address, "storage_longs", "felt", key=[ids.INSTRUMENT])[0]
        amount = context.signed_int(ids.amount)
        assert (ids.INITIAL_LONGS + amount == longs), f'longs error: {ids.INITIAL_LONGS + amount} different from {longs}'
    %}
    return ();
}

// TEST UPDATE SHORTS

@external
func setup_update_shorts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{ given(amount=strategy.integers(-ids.INITIAL_SHORTS, ids.RANGE_CHECK_BOUND - ids.INITIAL_SHORTS).filter(lambda x: x != 0)) %}
    return ();
}

@external
func test_update_shorts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=0);

    %{
        shorts = load(context.self_address, "storage_shorts", "felt", key=[ids.INSTRUMENT])[0]
        amount = context.signed_int(ids.amount)
        assert (ids.INITIAL_SHORTS + amount == shorts), f'shorts error: {ids.INITIAL_SHORTS + amount} different from {shorts}'
    %}
    return ();
}
