%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Vault, Stake
from contracts.perpx_v1_instrument import update_liquidity

@external
func provide_liquidity_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, owner : felt, instrument : felt
) -> ():
    Vault.provide_liquidity(amount=amount, owner=owner, instrument=instrument)
    update_liquidity(owner, instrument, amount)
    return ()
end

@external
func withdraw_liquidity_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, owner : felt, instrument : felt
) -> ():
    Vault.withdraw_liquidity(amount=amount, owner=owner, instrument=instrument)
    update_liquidity(owner, instrument, -amount)
    return ()
end

@view
func view_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (shares : felt):
    let (shares) = Vault.view_shares(instrument)
    return (shares=shares)
end

@view
func view_user_stake{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt
) -> (stake : Stake):
    let (stake) = Vault.view_user_stake(owner, instrument)
    return (stake=stake)
end

@view
func view_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (liquidity : felt):
    let (liquidity) = Vault.view_liquidity(instrument)
    return (liquidity=liquidity)
end
