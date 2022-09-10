%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.fees import Fees
from contracts.constants.perpx_constants import MAX_PRICE, MAX_AMOUNT, MAX_LIQUIDITY
from contracts.test.helpers import setup_helpers

#
# Setup
#

@external
func __setup__():
    setup_helpers()
    return ()
end

#
# Tests
#

@external
func test_limit_compute_imbalance_fees{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(rand : felt) -> ():
    alloc_locals
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity

    %{
        assume(ids.rand != 0)
        ids.price = ids.rand % (ids.MAX_PRICE)
        ids.amount = ids.rand % (ids.MAX_AMOUNT)
        ids.long = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.short = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.liquidity = ids.rand % (ids.MAX_LIQUIDITY)
        assume(ids.liquidity != 0)
    %}

    # compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        assert (ids.imbalance_fees) == imbalance_fees
    %}

    return ()
end

@external
func test_min_liquidity_compute_imbalance_fees{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(rand : felt) -> ():
    alloc_locals
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity

    %{
        assume(ids.rand != 0)
        ids.price = ids.rand % (ids.MAX_PRICE)
        ids.amount = ids.rand % (ids.MAX_AMOUNT)
        ids.long = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.short = ids.rand % (ids.MAX_PRICE*ids.MAX_AMOUNT)
        ids.liquidity = 1
    %}

    # compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        assert (ids.imbalance_fees) == imbalance_fees
    %}

    return ()
end

@external
func test_sanity_check_compute_fees_imbalance{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(rand : felt) -> ():
    alloc_locals

    local rand = rand
    local price
    local amount
    local long
    local short
    local liquidity

    %{
        ids.price = 10
        ids.amount = 10
        ids.long = 100
        ids.short = 200
        ids.liquidity = 1000
    %}

    # compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom
        #print('imbalance_fees python: ')
        #print(imbalance_fees)
        #print('imbalance_fees cairo: ')
        #print(ids.imbalance_fees)

        assert (ids.imbalance_fees) == context.unsigned_int(imbalance_fees), f'{ids.imbalance_fees} different from {context.unsigned_int(imbalance_fees)}'
    %}

    return ()
end

@external
func test_basis_compute_imbalance_fees{
    syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
}(rand : felt) -> ():
    alloc_locals
    local rand = rand

    local price
    local amount
    local long
    local short
    local liquidity

    %{
        assume(ids.rand != 0)
        ## different random numbers for each value
        ids.price, ids.amount, ids.long,  ids.short, ids.liquidity = context.get_random_values(ids.MAX_PRICE, ids.MAX_AMOUNT, ids.MAX_LIQUIDITY, ids.rand)
        assume(ids.liquidity != 0)
    %}

    # compute imbalance fees
    let (local imbalance_fees) = Fees.compute_imbalance_fee(
        price=price, amount=amount, long=long, short=short, liquidity=liquidity
    )

    %{
        nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
        denom = 2*ids.liquidity
        imbalance_fees = nom // denom

        assert ids.imbalance_fees == context.unsigned_int(imbalance_fees), f'imbalance fees {ids.imbalance_fees} different from {context.unsigned_int(imbalance_fees)}'
    %}

    return ()
end

# @external
# func test_basis_compute_imbalance_fees{
# syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr
# }(rand : felt) -> ():
# alloc_locals
# local rand = rand

# local price
# local amount
# local long
# local short
# local liquidity

# %{
# assume(ids.rand != 0)
# ## different random numbers for each value
# import random
# random.seed(ids.rand)
# ids.price = random.randint(0,ids.MAX_PRICE)
# print('price: ')
# print(ids.price)
# ids.amount = random.randint(0,ids.MAX_AMOUNT)
# print('amount: ')
# print(ids.amount)
# ids.long = random.randint(0,ids.MAX_PRICE*ids.MAX_AMOUNT)
# print('long: ')
# print(ids.long)
# ids.short = random.randint(0,ids.MAX_PRICE*ids.MAX_AMOUNT)
# print('short: ')
# print(ids.short)
# ids.liquidity = random.randint(0,ids.MAX_LIQUIDITY)
# print('liquidity: ')
# print(ids.liquidity)
# assume(ids.liquidity != 0)
# %}

# # compute imbalance fees
# let (local imbalance_fees) = Fees.compute_imbalance_fee(
# price=price, amount=amount, long=long, short=short, liquidity=liquidity
# )

# %{
# nom = ids.price * ids.amount * (2*ids.long + ids.price * ids.amount - 2* ids.short)
# denom = 2*ids.liquidity
# imbalance_fees = nom // denom

# assert ids.imbalance_fees == context.unsigned_int(imbalance_fees), f'imbalance fees {ids.imbalance_fees} different from {context.unsigned_int(imbalance_fees)}'
# %}

# return ()
# end
