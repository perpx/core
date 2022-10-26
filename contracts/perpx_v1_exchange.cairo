%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.utils.access_control import init_access_control
from contracts.perpx_v1_exchange.permissionless import (
    trade,
    close,
    liquidate,
    add_collateral,
    remove_collateral,
    add_liquidity,
    remove_liquidity,
)
from contracts.perpx_v1_exchange.mutables import (
    get_user_instruments,
    get_price,
    get_collateral,
    get_instrument_count,
)
from contracts.perpx_v1_exchange.owners import (
    update_prices,
    update_margin_parameters,
    flush_queue,
    update_prev_prices,
    _update_prev_prices,
)
from contracts.perpx_v1_exchange.storage import (
    storage_token,
    storage_instrument_count,
    storage_queue_limit,
)
from contracts.perpx_v1_exchange.setters import (
    set_fee_rate,
    set_last_update_price_delta,
    reset_is_escaping,
)
from contracts.perpx_v1_exchange.getters import (
    view_user_instruments,
    view_price,
    view_volatility,
    view_margin_parameters,
)

//
// Constructor
//

// @notice Exchange constructor
// @param owner The contract owner
// @param token The collateral token address
// @param instrument_count The number of instruments
// @param queue_limit The limit of orders in the operation queue
// @param prev_prices_len The length of the previous prices array
// @param prev_prices The previous prices array
@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    owner: felt,
    token: felt,
    instrument_count: felt,
    queue_limit: felt,
    prev_prices_len: felt,
    prev_prices: felt*,
) {
    assert instrument_count = prev_prices_len;
    init_access_control(owner);
    storage_token.write(token);
    storage_instrument_count.write(instrument_count);
    storage_queue_limit.write(queue_limit);
    _update_prev_prices(prev_prices_len=prev_prices_len, prev_prices=prev_prices, mult=1);
    return ();
}
