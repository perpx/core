%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.library.position import Info, Position
from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND
from helpers.helpers import setup_helpers

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 1;
const INSTRUMENT = 1;
//
// Setup
//

@external
func __setup__() {
    alloc_locals;
    setup_helpers();
    local address;
    %{ max_examples(200) %}

    return ();
}

@external
func test_update_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, amount: felt, fees: felt
) {
    alloc_locals;
    local address;
    %{ assume(ids.price < ids.LIMIT and ids.price*ids.amount < ids.LIMIT) %}
    Position.update_position(
        owner=OWNER, instrument=INSTRUMENT, price=price, amount=amount, fees=fees
    );
    let (local position: Info) = Position.position(owner=OWNER, instrument=INSTRUMENT);
    %{
        amount = context.signed_int(ids.amount)
        cost = context.signed_int(ids.position.cost)

        assert ids.position.fees == ids.fees, f'fees error, expected {ids.fees}, got {ids.position.fees}'
        assert cost == ids.price * amount // 10**6, f'cost error, expected {ids.price * amount}, got {cost}'
        assert ids.position.size == ids.amount, f'size error, expected {ids.amount}, got {ids.position.size}'
    %}
    return ();
}

@external
func test_close_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    close_price: felt, close_fees: felt
) {
    alloc_locals;
    local open_price;
    local amount;
    local open_fees;
    %{
        from random import randint
        assume(ids.close_price < ids.LIMIT)

        ids.open_price = randint(0, ids.LIMIT)
        range_amount = int(ids.LIMIT/ids.open_price)
        amount = randint(-range_amount, range_amount)
        ids.amount = PRIME - abs(amount) if amount < 0 else amount
        open_fees = randint(-ids.LIMIT, ids.LIMIT)
        ids.open_fees = PRIME - abs(open_fees) if open_fees < 0 else open_fees
    %}
    Position.update_position(
        owner=OWNER, instrument=INSTRUMENT, price=open_price, amount=amount, fees=open_fees
    );

    let (local delta) = Position.close_position(
        owner=OWNER, instrument=INSTRUMENT, price=close_price, fees=close_fees
    );
    %{
        delta = context.signed_int(ids.delta)
        close_fees = context.signed_int(ids.close_fees)
        cost = -(ids.open_price - ids.close_price) * amount // 10**6
        calc_delta = context.signed_int(-(ids.open_price - ids.close_price) * amount // 10**6 - close_fees - open_fees)
        correction = 1 if cost < 0 else 0
        calc_delta = context.signed_int(calc_delta) + correction
        assert delta == calc_delta, f'delta error, expected {calc_delta}, got {delta}'
    %}
    return ();
}
