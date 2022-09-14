%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.uint256 import Uint256, uint256_check, uint256_eq, uint256_not
from starkware.cairo.common.math import assert_not_zero

from openzeppelin.token.erc20.library import ERC20, ERC20_total_supply, ERC20_balances
from openzeppelin.security.safemath.library import SafeUint256

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name: felt, symbol: felt, decimals: felt
) {
    ERC20.initializer(name=name, symbol=symbol, decimals=decimals);
    return ();
}

@external
func mint{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    with_attr error_message("ERC20: amount is not a valid Uint256") {
        uint256_check(amount);
    }

    with_attr error_message("ERC20: cannot mint to the zero address") {
        assert_not_zero(recipient);
    }

    let (supply: Uint256) = ERC20_total_supply.read();
    with_attr error_message("ERC20: mint overflow") {
        let (new_supply: Uint256) = SafeUint256.add(supply, amount);
    }
    ERC20_total_supply.write(new_supply);

    let (balance: Uint256) = ERC20_balances.read(account=recipient);
    // overflow is not possible because sum is guaranteed to be less than total supply
    // which we check for overflow below
    let (new_balance: Uint256) = SafeUint256.add(balance, amount);
    ERC20_balances.write(recipient, new_balance);

    return ();
}

@external
func transfer_from{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sender: felt, recipient: felt, amount: Uint256
) {
    ERC20.transfer_from(sender=sender, recipient=recipient, amount=amount);
    return ();
}

@external
func approve{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    spender: felt, amount: Uint256
) {
    with_attr error_message("ERC20: amount is not a valid Uint256") {
        uint256_check(amount);
    }

    let (caller) = get_caller_address();
    ERC20._approve(caller, spender, amount);
    return ();
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    recipient: felt, amount: Uint256
) {
    ERC20.transfer(recipient=recipient, amount=amount);
    return ();
}
