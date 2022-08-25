%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.rewards import Reward
from contracts.perpx_v1_instrument import update_liquidity, get_liquidity, get_user_liquidity

@external
func provide_liquidity_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, address : felt, instrument : felt
) -> ():
    Reward.provide_liquidity(amount=amount, address=address, instrument=instrument)
    update_liquidity(address, instrument, amount)
    return ()
end

@view
func view_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (shares : felt):
    let (shares) = Reward.view_shares(instrument)
    return (shares=shares)
end

@view
func view_user_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt
) -> (shares : felt):
    let (shares) = Reward.view_user_shares(owner, instrument)
    return (shares=shares)
end

@view
func view_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (liquidity : felt):
    let (liquidity) = get_liquidity(instrument)
    return (liquidity=liquidity)
end

@view
func view_user_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt
) -> (liquidity : felt):
    let (liquidity) = get_user_liquidity(owner, instrument)
    return (liquidity=liquidity)
end
