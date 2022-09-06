%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import Uint256

from contracts.constants.perpx_constants import (
    MAX_LIQUIDITY,
    RANGE_CHECK_BOUND,
    MAX_PRICE,
    MAX_AMOUNT,
)

#
# Constants
#

const PRIME = 2 ** 251 + 17 * 2 ** 192 + 1
const OWNER = 12345
const ACCOUNT = 123
const INSTRUMENT_COUNT = 10

const ERC20_NAME = 8583683299111105110
const ERC20_SYMBOL = 85836867
const ERC20_DECIMALS = 6

#
# Interface
#

@contract_interface
namespace TestContract:
    func view_price_test(instrument : felt) -> ():
    end
    func update_prices_test(prices_len : felt, prices : felt*, instruments : felt):
    end
    func calculate_pnl_test(owner : felt, instruments : felt) -> (pnl : felt):
    end
    func add_liquidity_test(amount : felt, instrument : felt):
    end
    func remove_liquidity_test(amount : felt, instrument : felt):
    end
end

@contract_interface
namespace ERC20TestContract:
    func transferFrom(sender : felt, recipient : felt, amount : Uint256):
    end
    func approve(spender : felt, amount : Uint256):
    end
    func mint(recipient : felt, amount : Uint256):
    end
end

#
# Setup
#

@external
func __setup__():
    alloc_locals
    local address
    %{
        declared = declare("./contracts/test/ERC20_test.cairo")
        prepared = prepare(declared, [ids.ERC20_NAME, ids.ERC20_SYMBOL, ids.ERC20_DECIMALS])
        deploy(prepared)

        context.erc_contract_address = prepared.contract_address
        context.contract_address = deploy_contract("./contracts/test/perpx_v1_exchange_test.cairo", [ids.OWNER, prepared.contract_address, ids.INSTRUMENT_COUNT]).contract_address
    %}

    return ()
end

@external
func test_update_prices_revert{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    let (local arr) = alloc()
    local instruments
    local address
    local length
    %{
        assume(ids.random !=0)
        from random import randint, sample, random
        length = ids.random % ids.INSTRUMENT_COUNT
        length = length if length > 0 else 1
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.MAX_PRICE)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        sign = 1 if random() < 0.5 else -1
        ids.length = length + randint(1, length) * sign
        ids.instruments = instruments

        ids.address = context.contract_address
    %}

    %{
        stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) 
        expect_revert()
    %}
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr, instruments=instruments
    )
    %{ stop_prank_callable() %}
    return ()
end

@external
func test_update_prices_test{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    let (local arr) = alloc()
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        for i in range(length):
            memory[ids.arr + i] = randint(0, ids.MAX_PRICE)
        instruments = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            instruments |= 1 << bit
        ids.length = length
        ids.instruments = instruments

        ids.address = context.contract_address
    %}
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) %}
    TestContract.update_prices_test(
        contract_address=address, prices_len=length, prices=arr, instruments=instruments
    )
    %{
        stop_prank_callable() 
        instruments = ids.instruments
        mult = 1
        prices = []
        while instruments != 0:
            lsb = instruments & 1
            if lsb != 0:
                price = load(ids.address, "storage_oracles", "felt", key=[mult])[0]
                prices.append(price)
            mult *= 2
            instruments >>= 1
        for (i, p) in enumerate(prices):
            assert p == memory[ids.arr + i], f'instrument price error got {p}, expected {memory[ids.arr + i]}'
    %}
    return ()
end

@external
func test_calculate_pnl{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    random : felt
):
    alloc_locals
    local instruments
    local address
    local length
    %{
        from random import randint, sample
        length = ids.random % ids.INSTRUMENT_COUNT
        instruments = 0
        pnl = 0
        for bit in sample(range(ids.INSTRUMENT_COUNT), length):
            inst = 1 << bit
            instruments |= inst

            price = randint(0, ids.MAX_PRICE)
            amount = randint(0, ids.MAX_AMOUNT)
            cost = randint(0, ids.MAX_AMOUNT)
            pnl += price * amount - cost

            store(context.contract_address, "storage_oracles", [price], key=[inst])
            store(context.contract_address, "storage_positions", [0, cost, amount], key=[ids.ACCOUNT, inst])

        ids.length = length
        ids.instruments = instruments

        ids.address = context.contract_address
    %}
    let (local pnl) = TestContract.calculate_pnl_test(
        contract_address=address, owner=ACCOUNT, instruments=instruments
    )
    %{ stop_prank_callable = start_prank(ids.OWNER, target_contract_address=context.contract_address) %}
    %{
        stop_prank_callable() 
        assert pnl == ids.pnl, f'pnl error, expected {pnl}, got {ids.pnl}'
    %}
    return ()
end

@external
func test_add_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amount : felt
):
    alloc_locals
    local instruments
    local address
    local erc_address
    local instrument
    %{
        ids.instrument = ids.amount % ids.INSTRUMENT_COUNT
        ids.erc_address = context.erc_contract_address
        ids.address = context.contract_address
    %}
    %{
        if ids.amount > ids.RANGE_CHECK_BOUND:
            expect_revert(error_message="ERC20: amount is not a valid Uint256")
    %}
    # Mint to account
    ERC20TestContract.mint(
        contract_address=erc_address, recipient=ACCOUNT, amount=Uint256(amount, 0)
    )

    # prank the approval and the add liquidity calls
    %{
        erc_stop_prank_callable = start_prank(ids.ACCOUNT, target_contract_address=ids.erc_address)
        stop_prank_callable = start_prank(ids.ACCOUNT, target_contract_address=ids.address)
    %}
    ERC20TestContract.approve(
        contract_address=erc_address, spender=address, amount=Uint256(amount, 0)
    )
    %{
        erc_stop_prank_callable()
        if ids.amount < 1 or ids.amount > ids.MAX_LIQUIDITY:
            expect_revert(error_message="liquidity increase limited to 2**64")
    %}
    TestContract.add_liquidity_test(contract_address=address, amount=amount, instrument=instrument)

    %{
        stop_prank_callable() 
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.instrument])
        account_balance = load(ids.erc_address, "ERC20_balances", "Uint256", key=[ids.ACCOUNT])
        exchange_balance = load(ids.erc_address, "ERC20_balances", "Uint256", key=[ids.address])

        assert user_stake[0] == ids.amount, f'user stake amount error, expected {ids.amount}, got {user_stake[0]}'
        assert user_stake[1] == ids.amount*100, f'user stake shares error, expected {ids.amount * 100}, got {user_stake[1]}'
        assert account_balance == [0, 0], f'account balance error, expected [0, 0] got {account_balance}'
        assert exchange_balance == [ids.amount, 0], f'exchange balance error, expected [{ids.amount}, 0] got {exchange_balance}'
    %}

    return ()
end

@external
func test_remove_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    provide_amount : felt, remove_amount : felt
):
    alloc_locals
    local instruments
    local address
    local erc_address
    local instrument
    %{
        ids.instrument = ids.provide_amount % ids.INSTRUMENT_COUNT
        ids.erc_address = context.erc_contract_address
        ids.address = context.contract_address
    %}
    %{
        if ids.provide_amount > ids.RANGE_CHECK_BOUND:
            expect_revert(error_message="ERC20: amount is not a valid Uint256")
    %}
    # Mint to account
    ERC20TestContract.mint(
        contract_address=erc_address, recipient=ACCOUNT, amount=Uint256(provide_amount, 0)
    )

    # prank the approval and the add liquidity calls
    %{
        erc_stop_prank_callable = start_prank(ids.ACCOUNT, target_contract_address=ids.erc_address)
        stop_prank_callable = start_prank(ids.ACCOUNT, target_contract_address=ids.address)
    %}
    ERC20TestContract.approve(
        contract_address=erc_address, spender=address, amount=Uint256(provide_amount, 0)
    )
    %{
        erc_stop_prank_callable()
        if ids.provide_amount < 1 or ids.provide_amount > ids.MAX_LIQUIDITY:
            expect_revert(error_message="liquidity increase limited to 2**64")
    %}
    TestContract.add_liquidity_test(
        contract_address=address, amount=provide_amount, instrument=instrument
    )
    %{
        if ids.remove_amount < 1 or ids.remove_amount > ids.MAX_LIQUIDITY:
            expect_revert(error_message="liquidity decrease limited to 2**64")
        elif ids.remove_amount > ids.provide_amount:
            expect_revert(error_message="insufficient balance")
    %}
    TestContract.remove_liquidity_test(
        contract_address=address, amount=remove_amount, instrument=instrument
    )
    %{
        stop_prank_callable() 
        user_stake = load(ids.address, "storage_user_stake", "Stake", key=[ids.ACCOUNT, ids.instrument])
        diff = ids.provide_amount - ids.remove_amount
        shares = 100*ids.provide_amount - 100*ids.remove_amount

        assert user_stake[0] == diff, f'user stake amount error, expected {diff}, got {user_stake[0]}'
        assert user_stake[1] == shares, f'user stake shares error, expected {shares}, got {user_stake[1]}'
    %}

    return ()
end
