%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.position import Info
from contracts.constants.perpx_constants import MAX_AMOUNT, RANGE_CHECK_BOUND, MAX_PRICE

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
    local address;
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
        assume(ids.price < ids.MAX_PRICE and ids.price*ids.amount < ids.MAX_AMOUNT)
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
        amount = ids.amount
        cost = ids.position.cost
        if amount > PRIME/2:
            amount = -(PRIME - amount)
        if cost > PRIME/2:
            cost = -(PRIME-cost)
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
        assume(ids.price < ids.MAX_PRICE)
        ids.address = context.contract_address

        ids.open_price = randint(0, ids.MAX_PRICE)
        range_amount = int(ids.MAX_AMOUNT/ids.open_price)
        amount = randint(-range_amount, range_amount)
        ids.amount = PRIME - amount if amount < 0 else amount
        fees = randint(-ids.MAX_AMOUNT, ids.MAX_AMOUNT)
        ids.open_fees = PRIME - fees if fees < 0 else fees
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
        delta = ids.delta if ids.delta < PRIME/2 else -(PRIME-ids.delta)
        close_fees = ids.fees if ids.fees < PRIME/2 else -(PRIME-ids.fees)
        calc_delta = -(ids.open_price - ids.price) * amount - close_fees - ids.open_fees
        assert delta == calc_delta, f'delta error, expected {calc_delta}, got {delta}'
    %}
    return ();
}
