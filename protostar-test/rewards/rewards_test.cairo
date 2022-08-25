%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.rewards import Reward
from contracts.perpx_v1_instrument import update_liquidity, get_liquidity, get_user_liquidity

const INSTRUMENT = 1

@storage_var
func storage_shares_test() -> (value : felt):
end

@storage_var
func storage_user_shares_test(owner : felt) -> (value : felt):
end

@storage_var
func storage_liquidity_test() -> (value : felt):
end

@external
func test_provide_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    rand : felt
) -> ():
    alloc_locals
    local amount
    local owner
    local rand = rand
    %{
        ids.amount = ids.rand % (2**64)
        ids.owner = ids.rand % 5
    %}
    Reward.provide_liquidity(amount=amount, address=owner, instrument=INSTRUMENT)
    update_liquidity(owner=owner, instrument=INSTRUMENT, amount=amount)

    let (local shares) = Reward.view_shares(instrument=INSTRUMENT)
    let (local user_shares) = Reward.view_user_shares(owner=owner, instrument=INSTRUMENT)

    let (local liquidity) = storage_liquidity_test.read()

    let (local fuzz_shares) = storage_shares_test.read()
    let (local fuzz_user_shares) = storage_user_shares_test.read(owner)
    %{
        if ids.liquidity == 0:
            inc = ids.amount * 100
        else:
            inc = ids.amount * ids.fuzz_shares / ids.liquidity
        assert (ids.fuzz_shares + inc) == ids.shares, f'shares: {ids.fuzz_shares + inc} different from {ids.shares}'
        assert (ids.fuzz_user_shares + inc) == ids.user_shares, f'user_shares: {ids.fuzz_user_shares + inc} different from {ids.user_shares}'
    %}

    let new_liquidity = amount + liquidity
    storage_liquidity_test.write(new_liquidity)
    let new_shares = amount + fuzz_shares
    storage_shares_test.write(new_shares)
    let new_user_shares = amount + fuzz_user_shares
    storage_user_shares_test.write(owner, new_user_shares)

    return ()
end
