%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import unsigned_div_rem, assert_nn
from starkware.starknet.common.syscalls import get_block_timestamp

from contracts.constants.perpx_constants import SHARE_PRECISION, LIQUIDITY_PRECISION, LIMIT

//
// Structure
//
struct Stake {
    shares: felt,
    timestamp: felt,
}

//
// Storage
//
@storage_var
func storage_liquidity(instrument: felt) -> (liquidity: felt) {
}

@storage_var
func storage_shares(instrument: felt) -> (shares: felt) {
}

@storage_var
func storage_user_stake(owner: felt, instrument: felt) -> (stake: Stake) {
}

namespace Vault {
    //
    // Functions
    //

    // @notice Provide liquidity to the pool for target instrument
    // @dev Formula to implement is amount*shares/liquidity
    // @param amount The amount of liquidity provided (precision: 6)
    // @param owner The address of the provider
    // @param instrument The instrument to provide liquidity for
    func provide_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt, owner: felt, instrument: felt
    ) -> () {
        alloc_locals;
        local limit = LIMIT;

        let (shares) = storage_shares.read(instrument);
        let (user_stake) = storage_user_stake.read(owner, instrument);
        let (liquidity) = storage_liquidity.read(instrument);
        let new_liquidity = liquidity + amount;

        let (local ts) = get_block_timestamp();

        if (shares == 0) {
            let (factor, _) = unsigned_div_rem(SHARE_PRECISION, LIQUIDITY_PRECISION);
            let init_shares = amount * factor;
            with_attr error_message("shares limited to {limit}") {
                assert [range_check_ptr] = init_shares;
                assert [range_check_ptr + 1] = LIMIT - init_shares;
            }
            let range_check_ptr = range_check_ptr + 2;
            storage_shares.write(instrument, init_shares);
            storage_user_stake.write(owner, instrument, Stake(shares=init_shares, timestamp=ts));
            storage_liquidity.write(instrument, new_liquidity);
            return ();
        }

        let temp = amount * shares;
        let (shares_increase, _) = unsigned_div_rem(temp, liquidity);
        tempvar new_user_shares = user_stake.shares + shares_increase;
        tempvar new_shares = shares + shares_increase;
        with_attr error_message("shares limited to {limit}") {
            assert [range_check_ptr] = new_shares;
            assert [range_check_ptr + 1] = LIMIT - new_shares;
        }
        let range_check_ptr = range_check_ptr + 2;

        storage_shares.write(instrument, new_shares);
        storage_user_stake.write(owner, instrument, Stake(shares=new_user_shares, timestamp=ts));

        storage_liquidity.write(instrument, new_liquidity);
        return ();
    }

    // @notice Withdraw liquidity from the pool for target instrument
    // @param amount The amount of liquidity to withdraw (precision: 6)
    // @param owner The address of the provider
    // @param instrument The instrument to withdraw liquidity from
    func withdraw_liquidity{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
        amount: felt, owner: felt, instrument: felt
    ) -> () {
        let (user_stake) = storage_user_stake.read(owner, instrument);
        let (shares) = storage_shares.read(instrument);
        let (liquidity) = storage_liquidity.read(instrument);

        let temp_user = amount * shares;
        let (shares_sub, _) = unsigned_div_rem(temp_user, liquidity);
        let new_user_shares = user_stake.shares - shares_sub;

        with_attr error_message("insufficient balance") {
            assert_nn(new_user_shares);
        }

        let new_liquidity = liquidity - amount;
        let new_pool_shares = shares - shares_sub;

        storage_user_stake.write(
            owner, instrument, Stake(shares=new_user_shares, timestamp=user_stake.timestamp)
        );
        storage_shares.write(instrument, new_pool_shares);
        storage_liquidity.write(instrument, new_liquidity);

        return ();
    }
}
