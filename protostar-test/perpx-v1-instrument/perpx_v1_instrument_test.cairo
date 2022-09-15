%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Stake
from contracts.perpx_v1_instrument import (
    update_liquidity,
    update_long_short,
    storage_longs,
    storage_shorts,
)
from contracts.library.vault import storage_liquidity, storage_shares, storage_user_stake
from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND
from helpers.helpers import setup_helpers

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
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    setup_helpers();
    local address;
    %{ max_examples(200) %}

    storage_liquidity.write(INSTRUMENT, INITIAL_LIQUIDITY);
    storage_shares.write(INSTRUMENT, INITIAL_SHARES);
    storage_user_stake.write(
        OWNER,
        INSTRUMENT,
        Stake(amount=INITIAL_USER_LIQUIDITY, shares=INITIAL_USER_SHARES, timestamp=0),
    );
    storage_longs.write(INSTRUMENT, INITIAL_LONGS);
    storage_shorts.write(INSTRUMENT, INITIAL_SHORTS);

    return ();
}

@external
func test_update_liquidity_negative{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    let amount = PRIME - 2 ** 20;

    update_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    let (local liquidity) = storage_liquidity.read(INSTRUMENT);
    let (local shares) = storage_shares.read(INSTRUMENT);
    let (local user_stake: Stake) = storage_user_stake.read(OWNER, INSTRUMENT);

    %{
        amount = context.signed_int(ids.amount)
        share_dec = amount * ids.INITIAL_SHARES // ids.INITIAL_LIQUIDITY
        user_share_dec = amount * ids.INITIAL_USER_SHARES // ids.INITIAL_USER_LIQUIDITY
        assert(ids.INITIAL_LIQUIDITY + amount == ids.liquidity), f'liquidity: {ids.INITIAL_LIQUIDITY + amount} different from {ids.liquidity}'
        assert(ids.INITIAL_SHARES + share_dec == ids.shares), f'shares: {ids.INITIAL_SHARES + share_dec} different from {ids.shares}'
        assert(ids.INITIAL_USER_LIQUIDITY + amount == ids.user_stake.amount), f'user_amount: {ids.INITIAL_USER_LIQUIDITY + amount} different from {ids.user_stake.amount}'
        assert(ids.INITIAL_USER_SHARES + user_share_dec == ids.user_stake.shares), f'user_shares: {ids.INITIAL_USER_SHARES + user_share_dec} different from {ids.user_stake.shares}'
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

    let (local liquidity) = storage_liquidity.read(INSTRUMENT);
    let (local shares) = storage_shares.read(INSTRUMENT);
    let (local user_stake: Stake) = storage_user_stake.read(OWNER, INSTRUMENT);

    %{
        amount = context.signed_int(ids.amount)
        share_dec = amount * ids.INITIAL_SHARES // ids.INITIAL_LIQUIDITY
        user_share_dec = amount * ids.INITIAL_USER_SHARES // ids.INITIAL_USER_LIQUIDITY
        assert(ids.INITIAL_LIQUIDITY + amount == ids.liquidity), f'liquidity: {ids.INITIAL_LIQUIDITY + amount} different from {ids.liquidity}'
        assert(ids.INITIAL_SHARES + share_dec == ids.shares), f'shares: {ids.INITIAL_SHARES + share_dec} different from {ids.shares}'
        assert(ids.INITIAL_USER_LIQUIDITY + amount == ids.user_stake.amount), f'user_amount: {ids.INITIAL_USER_LIQUIDITY + amount} different from {ids.user_stake.amount}'
        assert(ids.INITIAL_USER_SHARES + user_share_dec == ids.user_stake.shares), f'user_shares: {ids.INITIAL_USER_SHARES + user_share_dec} different from {ids.user_stake.shares}'
    %}
    return ();
}

@external
func test_update_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local amount;
    %{
        assume(ids.random != 0)
        assume(ids.random < ids.LIMIT or ids.random > PRIME - ids.LIMIT)
        amount = ids.random
        if amount > PRIME / 2 and amount < PRIME - ids.INITIAL_USER_LIQUIDITY:
            amount = PRIME - (amount % ids.INITIAL_USER_LIQUIDITY + 1)
        ids.amount = amount
    %}
    update_liquidity(amount=amount, owner=OWNER, instrument=INSTRUMENT);

    let (local liquidity) = storage_liquidity.read(INSTRUMENT);
    let (local shares) = storage_shares.read(INSTRUMENT);
    let (local user_stake: Stake) = storage_user_stake.read(OWNER, INSTRUMENT);

    %{
        import math
        amount = context.signed_int(ids.amount)
        share_inc = amount * ids.INITIAL_SHARES
        user_share_inc = amount * ids.INITIAL_USER_SHARES
        share_inc = share_inc // ids.INITIAL_LIQUIDITY if share_inc > 0 else math.ceil(share_inc/ids.INITIAL_LIQUIDITY)
        user_share_inc = user_share_inc // ids.INITIAL_USER_LIQUIDITY if user_share_inc > 0 else math.ceil(user_share_inc/ids.INITIAL_USER_LIQUIDITY)
        assert(ids.INITIAL_LIQUIDITY + amount == ids.liquidity), f'liquidity: {ids.INITIAL_LIQUIDITY + amount} different from {ids.liquidity}'
        assert(ids.INITIAL_SHARES + share_inc == ids.shares), f'shares: {ids.INITIAL_SHARES + share_inc} different from {ids.shares}'
        assert(ids.INITIAL_USER_LIQUIDITY + amount == ids.user_stake.amount), f'user_amount: {ids.INITIAL_USER_LIQUIDITY + amount} different from {ids.user_stake.amount}'
        assert(ids.INITIAL_USER_SHARES + user_share_inc == ids.user_stake.shares), f'user_shares: {ids.INITIAL_USER_SHARES + user_share_inc} different from {ids.user_stake.shares}'
    %}
    return ();
}

@external
func test_update_longs{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    %{
        assume(ids.amount != 0)
        if (ids.amount > PRIME/2 and PRIME - ids.amount%PRIME > ids.INITIAL_LONGS) or (ids.amount < PRIME/2 and ids.amount + ids.INITIAL_LONGS > ids.RANGE_CHECK_BOUND):
            expect_revert(error_message="negative longs")
    %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=1);
    let (local longs) = storage_longs.read(INSTRUMENT);

    %{
        amount = context.signed_int(ids.amount)
        assert (ids.INITIAL_LONGS + amount == ids.longs), f'longs: {ids.INITIAL_LONGS + amount} different from {ids.longs}'
    %}
    return ();
}

@external
func test_update_shorts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    amount: felt
) {
    alloc_locals;
    %{
        assume(ids.amount != 0)
        if (ids.amount > PRIME/2 and PRIME - ids.amount%PRIME > ids.INITIAL_SHORTS) or (ids.amount < PRIME/2 and ids.amount + ids.INITIAL_SHORTS > ids.RANGE_CHECK_BOUND):
            expect_revert(error_message="negative shorts")
    %}
    update_long_short(amount=amount, instrument=INSTRUMENT, is_long=0);
    let (local shorts) = storage_shorts.read(INSTRUMENT);

    %{
        amount = context.signed_int(ids.amount)
        assert (ids.INITIAL_SHORTS + amount == ids.shorts), f'shorts: {ids.INITIAL_SHORTS + amount} different from {ids.shorts}'
    %}
    return ();
}
