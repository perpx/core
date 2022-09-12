%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.perpx_v1_exchange import (
    update_prices,
    init_prev_prices,
    _update_volatility,
    update_margin_parameters,
    get_price,
    add_liquidity,
    remove_liquidity,
    add_collateral,
    _calculate_pnl,
    _calculate_fees,
    _verify_length,
    Parameter,
)
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
func init_prev_prices_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_prices_len : felt, prev_prices : felt*
) -> ():
    init_prev_prices(prev_prices_len=prev_prices_len, prev_prices=prev_prices)
    return ()
end

@external
func update_volatility_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    instrument_count : felt
) -> ():
    _update_volatility(instrument_count=instrument_count, mult=1)
    return ()
end

@external
func update_margin_parameters_test{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(parameters_len : felt, parameters : Parameter*, instruments : felt):
    update_margin_parameters(
        parameters_len=parameters_len, parameters=parameters, instruments=instruments
    )
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
func verify_length_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    length : felt, instruments : felt
):
    _verify_length(length=length, instruments=instruments)
    return ()
end
