%lang starknet

from contracts.perpx_v1_exchange import (
    update_prices,
    get_price,
    _calculate_pnl,
    _calculate_fees,
    add_liquidity,
    remove_liquidity,
    add_collateral,
)
from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.position import Position

@view
func view_price_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument : felt
) -> (price : felt):
    let (price) = get_price(instrument)
    return (price=price)
end

@external
func update_prices_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prices_len : felt, prices : felt*, instruments : felt
) -> ():
    update_prices(prices_len=prices_len, prices=prices, instruments=instruments)
    return ()
end

@external
func update_position_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : felt, instrument : felt, price : felt, amount : felt, fees : felt
) -> ():
    Position.update_position(
        owner=address, instrument=instrument, price=price, amount=amount, fees=fees
    )
    return ()
end

@external
func close_position_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instrument : felt, price : felt, fees : felt
) -> ():
    Position.close_position(owner=owner, instrument=instrument, price=price, fees=fees)
    return ()
end

@external
func calculate_pnl_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instruments : felt
) -> (pnl : felt):
    let (pnl) = _calculate_pnl(owner=owner, instruments=instruments, mult=1)
    return (pnl=pnl)
end

@external
func calculate_fees_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    owner : felt, instruments : felt
) -> (fees : felt):
    let (fees) = _calculate_fees(owner=owner, instruments=instruments, mult=1)
    return (fees=fees)
end

@external
func add_liquidity_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt
):
    add_liquidity(amount=amount, instrument=instrument)
    return ()
end

@external
func remove_liquidity_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt, instrument : felt
):
    remove_liquidity(amount=amount, instrument=instrument)
    return ()
end

@external
func add_collateral_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt
):
    add_collateral(amount=amount)
    return ()
end
