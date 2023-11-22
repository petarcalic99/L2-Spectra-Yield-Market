%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt_felt, assert_not_zero, assert_nn


////Events

@event
func rates_updated(4626_address: felt, date: felt, rate: felt) {
}


////Storage_vars

//Mapping from (ERC4626 pt to) date to rate.
@storage_var
func daily_rate(4626_address: felt, date: felt) -> (rate: felt) {
}

// (mapping from ERC4626 pt to) last poked date
@storage_var
func last_poked_date(4626_address: felt) -> (date: felt) {
}


////Setters

//@dev Stores the current rate (underlying to IBT) of the given pt.
//@param pt The pt contract to store the rate of.
@l1_handler
func poke_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(from_address: felt, rate: felt) {
    alloc_locals;

    //update last poked date
    
    //update daily rate
    
    //rates_updated.emit()

    return();
}

////Getters

// @notice Getter for the rate (underlying to IBT) of a given pt at a given date
// @param pt Address of the pt to get the rate of.
// @param date Date of the rate to get (in number of days since Jan. 1st 1970 UTC GMT).
// @return Rate of the given pt at the given date.
@external
func get_rate_on_date{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(4626_address: felt, date: felt) -> (rate: felt) {
    let (stored_rate) = daily_rate.read(4626_address, date);
    return(rate = stored_rate);
}

//@notice Getter for the last date the rate got poked for the given principalToken.
//@param pt Address of the pt to get the last poked date of.
//@return The date of the last time a poke happened on the given principalToken.
@external
func get_last_poked_date{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(4626_address: felt) -> (date: felt) {
    let (stored_date) = last_poked_date.read(4626_address);
    return(date = stored_date);
}