%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

from contracts.constants.perpx_constants import LIMIT, RANGE_CHECK_BOUND, LIQUIDITY_PRECISION

//
// Constants
//

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1;
const OWNER = 12345;
const TOKEN_ADDRESS = 1234567;
const INSTRUMENT_COUNT = 10;
const QUEUE_LIMIT = 200;

//
// Setup
//

@external
func __setup__{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local address;
    %{
        from random import randint
        call_data = [ids.OWNER, ids.TOKEN_ADDRESS, ids.INSTRUMENT_COUNT, ids.QUEUE_LIMIT, ids.INSTRUMENT_COUNT]
        for x in range(ids.INSTRUMENT_COUNT):
            call_data.append(randint(1, ids.LIMIT))
        context.contract_address = deploy_contract("./contracts/perpx_v1_exchange.cairo", call_data).contract_address
        context.call_data = call_data
    %}
    return ();
}

@external
func test_constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    %{
        owner = load(context.contract_address, "Ownable_owner", "felt")[0]
        token = load(context.contract_address, "storage_token", "felt")[0]
        count = load(context.contract_address, "storage_instrument_count", "felt")[0]
        limit = load(context.contract_address, "storage_queue_limit", "felt")[0]
        prev_prices = [load(context.contract_address, "storage_prev_oracles", "felt", key=[2**i])[0] for i in range(ids.INSTRUMENT_COUNT)]

        assert owner == context.call_data[0], f'owner error, expected {context.call_data[0]}, got {owner}'
        assert token == context.call_data[1], f'token error, expected {context.call_data[1]}, got {token}'
        assert count == context.call_data[2], f'count error, expected {context.call_data[2]}, got {count}'
        assert limit == context.call_data[3], f'limit error, expected {context.call_data[3]}, got {count}'
        assert count == context.call_data[4], f'count error, expected {context.call_data[4]}, got {count}'
        assert prev_prices == context.call_data[5:], f'prev prices error, expected {context.call_data[5:]}, got {prev_prices}'
    %}
    return ();
}
