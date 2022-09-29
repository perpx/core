%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from contracts.library.vault import Vault, Stake

//
// Constants
//

const OWNER = 1;
const INSTRUMENT = 1;

//
// Setup
//

@external
func __setup__() {
    return ();
}

// TEST WITHDRAW LIQUIDITY

@external
func test_withdraw_liquidity_revert{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}() {
    alloc_locals;
    // provide then try to retrieve more
    Vault.provide_liquidity(amount=100, owner=OWNER, instrument=INSTRUMENT);
    %{ expect_revert(error_message="insufficient balance") %}
    Vault.withdraw_liquidity(amount=101, owner=OWNER, instrument=INSTRUMENT);
    return ();
}
