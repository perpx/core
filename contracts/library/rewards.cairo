%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math_cmp import is_nn
from starkware.cairo.common.math import unsigned_div_rem

from contracts.perpx_v1_instrument import get_liquidity
from contracts.constants.perpx_constants import SHARE_PRECISION, LIQUIDITY_PRECISION

#
# Storage
#

@storage_var
func storage_shares(instrument : felt) -> (shares : felt):
end

@storage_var
func storage_user_shares(owner : felt, instrument : felt) -> (shares : felt):
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

    func view_user_shares{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        owner : felt, instrument : felt
    ) -> (shares : felt):
        let (shares) = storage_user_shares.read(owner, instrument)
        return (shares=shares)
    end

    # @notice Provide liquidity to the pool for target instrument
    # @dev Formula to implement is amount/(liquidity+amount) /(1-(amount/(liquidity+amount))) * shares
    # @param amount The amount of liquidity provided (precision: 6)
    # @param address The address of the provider
    # @param instrument The instrument to provide liquidity for
    func provide_liquidity{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        amount : felt, address : felt, instrument : felt
    ) -> ():
        alloc_locals

        let (shares) = storage_shares.read(instrument)
        let (user_share) = storage_user_shares.read(address, instrument)
        let (liquidity) = get_liquidity(instrument)

        if shares == 0:
            let (factor, _) = unsigned_div_rem(SHARE_PRECISION, LIQUIDITY_PRECISION)
            let init_shares = amount * factor
            storage_shares.write(instrument, init_shares)
            storage_user_shares.write(address, instrument, init_shares)
            return ()
        end

        let temp = amount * shares
        let (shares_increase, _) = unsigned_div_rem(temp, liquidity)
        tempvar new_user_shares = user_share + shares_increase
        storage_user_shares.write(address, instrument, new_user_shares)

        tempvar new_shares = shares + shares_increase
        storage_shares.write(instrument, new_shares)

        return ()
    end
end
