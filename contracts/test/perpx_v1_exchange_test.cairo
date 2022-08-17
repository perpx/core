%lang starknet

from contracts.perpx_v1_exchange import update_prices, get_price
from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.utils.access_control import owner

@view
func view_price_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (price : felt):
    let (price) = get_price(instrument)
    return (price=price)
end

@view
func view_owner_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
    owner : felt
):
    let (_owner) = owner()
    return (owner=_owner)
end

@external
func update_prices_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prices_len : felt, prices : felt*, instruments : felt
) -> ():
    update_prices(prices_len=prices_len, prices=prices, instruments=instruments)
    return ()
end
