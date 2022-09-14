%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.position import Info
from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND
from helpers.helpers import setup_helpers

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 1;
const INSTRUMENT = 1;

//
// Interface
//

@contract_interface
namespace TestContract {
    func get_delta_test() -> (delt: felt) {
    }
    func get_position_test(owner: felt, instrument: felt) -> (position: Info) {
    }
    func update_test(owner: felt, instrument: felt, price: felt, amount: felt, fees: felt) {
    }
    func close_test(owner: felt, instrument: felt, price: felt, fees: felt) {
    }
}

//
// Setup
//

@external
func __setup__() {
    alloc_locals;
    setup_helpers();
    local address;
    %{ max_examples(200) %}
    %{ context.contract_address = deploy_contract("./contracts/test/position_test.cairo").contract_address %}

    return ();
}

@external
func test_update_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, amount: felt, fees: felt
) {
    alloc_locals;
    local address;
    %{
        assume(ids.price < ids.LIMIT and ids.price*ids.amount < ids.LIMIT)
        ids.address = context.contract_address
    %}
    TestContract.update_test(
        contract_address=address,
        owner=OWNER,
        instrument=INSTRUMENT,
        price=price,
        amount=amount,
        fees=fees,
    );
    let (local position: Info) = TestContract.get_position_test(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT
    );
    %{
        amount = context.signed_int(ids.amount)
        cost = context.signed_int(ids.position.cost)

        assert ids.position.fees == ids.fees, f'fees error, expected {ids.fees}, got {ids.position.fees}'
        assert cost == ids.price * amount, f'cost error, expected {ids.price * amount}, got {cost}'
        assert ids.position.size == ids.amount, f'size error, expected {ids.amount}, got {ids.position.size}'
    %}
    return ();
}

@external
func test_close_position{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    price: felt, fees: felt
) {
    alloc_locals;
    local address;
    local open_price;
    local amount;
    local open_fees;
    %{
        from random import randint
        assume(ids.price < ids.LIMIT)
        ids.address = context.contract_address

        ids.open_price = randint(0, ids.LIMIT)
        range_amount = int(ids.LIMIT/ids.open_price)
        amount = randint(-range_amount, range_amount)
        ids.amount = PRIME - abs(amount) if amount < 0 else amount
        fees = randint(-ids.LIMIT, ids.LIMIT)
        ids.open_fees = PRIME - abs(fees) if fees < 0 else fees
    %}
    TestContract.update_test(
        contract_address=address,
        owner=OWNER,
        instrument=INSTRUMENT,
        price=open_price,
        amount=amount,
        fees=open_fees,
    );

    TestContract.close_test(
        contract_address=address, owner=OWNER, instrument=INSTRUMENT, price=price, fees=fees
    );
    let (local delta) = TestContract.get_delta_test(contract_address=address);
    %{
        delta = context.signed_int(ids.delta)
        close_fees = context.signed_int(ids.fees)
        calc_delta = -(ids.open_price - ids.price) * amount - close_fees - ids.open_fees
        assert delta == calc_delta, f'delta error, expected {calc_delta}, got {delta}'
    %}
    return ();
}
