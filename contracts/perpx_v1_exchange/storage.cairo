%lang starknet

from contracts.perpx_v1_exchange.structures import Parameter, QueuedOperation

//
// Storage
//

@storage_var
func storage_user_instruments(owner: felt) -> (instruments: felt) {
}

@storage_var
func storage_oracles(instrument: felt) -> (price: felt) {
}

@storage_var
func storage_prev_oracles(instrument: felt) -> (price: felt) {
}

@storage_var
func storage_volatility(instrument: felt) -> (volatility: felt) {
}

@storage_var
func storage_margin_parameters(instrument: felt) -> (param: Parameter) {
}

@storage_var
func storage_collateral(owner: felt) -> (amount: felt) {
}

@storage_var
func storage_operations_queue(index: felt) -> (operation: QueuedOperation) {
}

@storage_var
func storage_operations_count() -> (count: felt) {
}

@storage_var
func storage_token() -> (address: felt) {
}

@storage_var
func storage_instrument_count() -> (instrument_count: felt) {
}

@storage_var
func is_paused() -> (paused: felt) {
}
