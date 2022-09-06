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
