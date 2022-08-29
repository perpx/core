%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.math import unsigned_div_rem, assert_nn
from starkware.starknet.common.syscalls import get_block_timestamp

from contracts.perpx_v1_instrument import get_liquidity
from contracts.constants.perpx_constants import SHARE_PRECISION, LIQUIDITY_PRECISION

#
# Structure
#
struct Stake:
    member amount : felt
    member shares : felt
    member timestamp : felt
end

#
# Storage
#

@storage_var
func storage_shares(instrument : felt) -> (shares : felt):
end

@storage_var
func storage_user_stake(owner : felt, instrument : felt) -> (stake : Stake):
end

namespace Reward:
    #
    # Functions
    #
    func view_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        instrument : felt
    ) -> (shares : felt):
        let (shares) = storage_shares.read(instrument)
        return (shares=shares)
    end

    func view_user_stake{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, instrument : felt
    ) -> (stake : Stake):
        let (stake) = storage_user_stake.read(owner, instrument)
        return (stake=stake)
    end

    # @notice Provide liquidity to the pool for target instrument
    # @dev Formula to implement is amount*shares/liquidity
    # @param amount The amount of liquidity provided (precision: 6)
    # @param address The address of the provider
    # @param instrument The instrument to provide liquidity for
    func provide_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : felt, address : felt, instrument : felt
    ) -> ():
        alloc_locals

        let (shares) = storage_shares.read(instrument)
        let (user_stake) = storage_user_stake.read(address, instrument)
        let (liquidity) = get_liquidity(instrument)

        let (local ts) = get_block_timestamp()

        if shares == 0:
            let (factor, _) = unsigned_div_rem(SHARE_PRECISION, LIQUIDITY_PRECISION)
            let init_shares = amount * factor
            storage_shares.write(instrument, init_shares)
            storage_user_stake.write(
                address, instrument, Stake(amount=amount, shares=init_shares, timestamp=ts)
            )
            return ()
        end

        let temp = amount * shares
        let (shares_increase, _) = unsigned_div_rem(temp, liquidity)
        tempvar new_user_shares = user_stake.shares + shares_increase
        tempvar new_amount = user_stake.amount + amount
        storage_user_stake.write(
            address, instrument, Stake(amount=new_amount, shares=new_user_shares, timestamp=ts)
        )

        tempvar new_shares = shares + shares_increase
        storage_shares.write(instrument, new_shares)

        return ()
    end

    # @notice Withdraw liquidity from the pool for target instrument
    # @param amount The amount of liquidity to withdraw (precision: 6)
    # @param address The address of the provider
    # @param instrument The instrument to withdraw liquidity from
    func withdraw_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : felt, address : felt, instrument : felt
    ) -> ():
        let (user_stake) = storage_user_stake.read(address, instrument)

        with_attr error_message("null amount"):
            assert_nn(amount - 1)
        end

        let new_amount = user_stake.amount - amount
        with_attr error_message("insufficient balance"):
            assert_nn(new_amount)
        end

        let (shares) = storage_shares.read(instrument)
        let (liquidity) = get_liquidity(instrument)

        let temp_user = amount * user_stake.shares
        let (user_shares_sub, _) = unsigned_div_rem(temp_user, user_stake.amount)
        let new_user_shares = user_stake.shares - user_shares_sub

        let temp_share = amount * shares
        let (pool_shares_sub, _) = unsigned_div_rem(temp_share, liquidity)
        let new_pool_shares = shares - pool_shares_sub

        storage_user_stake.write(
            address,
            instrument,
            Stake(amount=new_amount, shares=new_user_shares, timestamp=user_stake.timestamp),
        )
        storage_shares.write(instrument, new_pool_shares)

        return ()
    end
end
