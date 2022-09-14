%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Stake
from contracts.constants.perpx_constants import MAX_LIQUIDITY, RANGE_CHECK_BOUND

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
// Interface
//

@contract_interface
namespace TestContract {
    func update_liquidity_test(amount: felt, owner: felt, instrument: felt) -> () {
    }
    func view_shares(instrument: felt) -> (shares: felt) {
    }
    func view_user_stake(owner: felt, instrument: felt) -> (stake: Stake) {
    }
    func view_liquidity(instrument: felt) -> (liquidity: felt) {
    }
    func update_long_short_test(amount: felt, instrument: felt, is_long: felt) {
    }
    func view_longs(instrument: felt) -> (longs: felt) {
    }
    func view_shorts(instrument: felt) -> (shorts: felt) {
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
        context.contract_address = deploy_contract("./contracts/test/perpx_v1_instrument_test.cairo").contract_address 
        ids.address = context.contract_address

        store(context.contract_address, "storage_liquidity", [ids.INITIAL_LIQUIDITY], key=[ids.INSTRUMENT])
        store(context.contract_address, "storage_shares", [ids.INITIAL_SHARES], key=[ids.INSTRUMENT])
        store(context.contract_address, "storage_user_stake", [ids.INITIAL_USER_LIQUIDITY, ids.INITIAL_USER_SHARES], key=[ids.OWNER, ids.INSTRUMENT])

        store(context.contract_address, "storage_longs", [ids.INITIAL_LONGS], key=[ids.INSTRUMENT])
        store(context.contract_address, "storage_shorts", [ids.INITIAL_SHORTS], key=[ids.INSTRUMENT])
    %}

    return ();
}

@external
func test_update_liquidity_negative{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    local address;
    %{ ids.address = context.contract_address %}
    let amount = PRIME - 2 ** 20;

    TestContract.update_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    let (local liquidity) = TestContract.view_liquidity(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local shares) = TestContract.view_shares(contract_address=address, instrument=INSTRUMENT);
    let (local user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        amount = ids.amount
        if amount > (PRIME/2):
            amount = -(PRIME - amount)
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
    local address;
    %{ ids.address = context.contract_address %}
    let amount = 2 ** 30;

    TestContract.update_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    let (local liquidity) = TestContract.view_liquidity(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local shares) = TestContract.view_shares(contract_address=address, instrument=INSTRUMENT);
    let (local user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        amount = ids.amount
        if amount > (PRIME/2):
            amount = -(PRIME - amount)
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
    local amount: felt;
    local random = random;
    local address;
    %{
        ids.address = context.contract_address
        assume(ids.random != 0)
        assume(ids.random < ids.MAX_LIQUIDITY or ids.random > PRIME - ids.MAX_LIQUIDITY)
        amount = ids.random
        if amount > PRIME / 2 and amount < PRIME - ids.INITIAL_USER_LIQUIDITY:
            amount = PRIME - (amount % ids.INITIAL_USER_LIQUIDITY + 1)
        ids.amount = amount
    %}
    TestContract.update_liquidity_test(
        contract_address=address, amount=amount, owner=OWNER, instrument=INSTRUMENT
    );

    let (local liquidity) = TestContract.view_liquidity(
        contract_address=address, instrument=INSTRUMENT
    );
    let (local shares) = TestContract.view_shares(contract_address=address, instrument=INSTRUMENT);
    let (local user_stake: Stake) = TestContract.view_user_stake(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );

    %{
        import math
        amount = ids.amount
        if amount > (PRIME/2):
            amount = -(PRIME - amount)
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
    random: felt
) {
    alloc_locals;
    local address;
    local amount = random;
    %{
        ids.address = context.contract_address
        # assume(ids.amount != 0)
        if (ids.amount > PRIME/2 and PRIME - ids.amount%PRIME > ids.INITIAL_LONGS) or (ids.amount < PRIME/2 and ids.amount + ids.INITIAL_LONGS > ids.RANGE_CHECK_BOUND):
                expect_revert(error_message="negative longs")
    %}
    TestContract.update_long_short_test(
        contract_address=address, amount=amount, instrument=INSTRUMENT, is_long=1
    );

    let (local longs) = TestContract.view_longs(contract_address=address, instrument=INSTRUMENT);

    %{
        amount = ids.amount if ids.amount < PRIME/2 else - (PRIME - ids.amount)
        assert (ids.INITIAL_LONGS + amount == ids.longs), f'longs: {ids.INITIAL_LONGS + amount} different from {ids.longs}'
    %}
    return ();
}

@external
func test_update_shorts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    random: felt
) {
    alloc_locals;
    local address;
    local amount = random;
    %{
        import math
        ids.address = context.contract_address
        assume(ids.amount != 0)
        if (ids.amount > PRIME/2 and PRIME - ids.amount%PRIME > ids.INITIAL_SHORTS) or (ids.amount < PRIME/2 and ids.amount + ids.INITIAL_SHORTS > ids.RANGE_CHECK_BOUND):
                expect_revert(error_message="negative shorts")
    %}
    TestContract.update_long_short_test(
        contract_address=address, amount=amount, instrument=INSTRUMENT, is_long=0
    );

    let (local shorts) = TestContract.view_shorts(contract_address=address, instrument=INSTRUMENT);

    %{
        amount = ids.amount if ids.amount < PRIME/2 else -(PRIME - ids.amount)
        assert (ids.INITIAL_SHORTS + amount == ids.shorts), f'shorts: {ids.INITIAL_SHORTS + amount} different from {ids.shorts}'
    %}
    return ();
}
