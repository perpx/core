%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

//
// Structures
//

struct BatchedTrade {
    valid_until: felt,
    amount: felt,
}

struct BatchedCollateral {
    valid_until: felt,
    amount: felt,
}

// k and lambda are stored as fixed point values 64x61
struct Parameter {
    k: felt,
    lambda: felt,
}
