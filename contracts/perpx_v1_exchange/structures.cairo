%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin

//
// Structures
//

struct QueuedOperation {
    caller: felt,
    amount: felt,
    instrument: felt,
    valid_until: felt,
    operation: felt,
}

struct Operation {
    trade: felt,
    close: felt,
    remove_collateral: felt,
}

// k and lambda are stored as fixed point values 64x61
struct Parameter {
    k: felt,
    lambda: felt,
}
