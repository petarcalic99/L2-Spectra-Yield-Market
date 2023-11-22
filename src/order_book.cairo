%lang starknet

// Starkware dependencies
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.math import assert_not_zero
from starkware.cairo.common.usort import usort
from starkware.cairo.common.find_element import find_element
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math_cmp import is_le
from starkware.starknet.common.syscalls import get_caller_address
from starkware.starknet.common.syscalls import get_block_timestamp

//Cloned from Gaetbout's bit manipulation repository
from lib.cairo_contracts.bits_manipulation import actual_set_element_at, actual_get_element_at

@contract_interface
namespace Ibridge_l2 {
    func increment_balance_underlying(_user_address: felt, _amount: felt) {
    }

    func decrement_balance_underlying(_user_address: felt, _amount: felt) {
    }

    func get_user_balance_YT(_user_address: felt) -> (balance: felt) {
    }
}


const BITS_SIZE = 120;
const MAX_PER_FELT = 2;  // 251  = 2*120 + 11

//Seconds in a day
const DAY = 86400;

//@notice Checks that the given timestamps corresponds to a time at 00:00
//@dev Checks that its a multiple of 86400, as unix time starts at 00:00
//@param timestamp: Timestamp of the wanted day(monday at 00:00 represented at the timestamp in seconds on monday at 00:00.)
//@return true if the timestamp is a multiple of 86400.
func check_day_00{range_check_ptr}(timestamp: felt) -> (bool: felt){
    let (_, r) = unsigned_div_rem(timestamp, DAY);  
    if(r==0){
        return(bool = 1);
    }
    return(bool = 0);
}

// @notice Will return the number encoded at for a certain number of bits
// @dev This method can fail
// @param input: The felt from which it needs to be extracted from
// @param at: The position of the element that needs to be extracted, starts a 0
// @return response: The felt that was extracted at the position asked, on the number of bits asked
@view
func get_element_at{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(input: felt, at: felt) -> (response: felt) {
    return actual_get_element_at(input, at * BITS_SIZE, BITS_SIZE);
}

// @notice Will return the new felt with the felt encoded at a certain position on a certain number of bits
// @dev This method can fail
// @param input: The felt in which it needs to be included in
// @param at: The position of the element that needs to be added, starts a 0
// @param element: The element that needs to be encoded
// @return response: The new felt containing the encoded value a the given position on the given number of bits
@view
func set_element_at{
    bitwise_ptr: BitwiseBuiltin*, syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr
}(input: felt, at: felt, element: felt) -> (response: felt) {
    return actual_set_element_at(input, at * BITS_SIZE, BITS_SIZE, element);
}

////STORAGE VARIABLES

struct Order {
    amount: felt,       //Amount of YT to buy/sell daily
    price: felt,        //Price for one YT per day
    direction: felt,    //direction 1 = selling order, 0 = buying order
    active: felt,       //Boolean indiacting if an order has been canceled, not used for now. 
    start_date: felt,   //Starting date of the order (timestamp in seconds)
    end_date: felt,     //Ending date of the order (timestamp in seconds)
}


// The calendar of owned YT's
@storage_var
func user_balance(day: felt, user_address: felt) -> (res: felt) {
}

@storage_var
func claimable_yield(user: felt) -> (res: felt) {
}

@storage_var
func last_date_updated(user: felt) -> (day: felt) {
}


@storage_var
func bridge_address() -> (address: felt) {
}

@external
func set_bridge{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    bridge_address.write(address);
    return();
}

//Not used for now
@storage_var
func last_filled_day(user: felt) -> (day: felt) {
}


// @notice Reference of each order.
// @dev Pointer from an order id to the refering Order struct containing the order's details.
// @param order_id The order id.
// @return return the coresponding Order struct.
@storage_var
func order_ref(user: felt, order_id: felt) -> (user_order: Order) {
}

// @notice Counter of the total orders created.
// @dev Used for incrementing the order_ref storage variable..
// @return Current id thats need to be incremented by one before assigning to an order. 
// @custom We can do without those variables by traversing the whole list an asigning the next value that returned 0.
// @custom On the other side, the update of coumnter variable should be amortized when a lot of writes exist as only the final value will be sent to L1. 
@storage_var
func order_ref_ctr(user: felt) -> (ctr: felt) {
}

// @notice Array of orders on a certain day. The order book.
// @dev Mapping a day to a list of references to a price and the refering order.
// @param day: The order day we want to look available orders
// @param idx: counter acting as a reference to the corresponding tuple reference.
// @return The reference of the tuple (price, order_id) and the amount AVAILABLE.
// @custom If we can pack the two(three) variables into one, we can remove the ref. 
@storage_var
func order_book_s(day: felt, idx: felt) -> (tuple_ref_x_order_amount: (felt, felt)) {
}


@storage_var
func order_book_b(day: felt, idx: felt) -> (tuple_ref_x_order_amount: (felt, felt)) {
}

// @notice Reference of each order in the orderbook and its period immutable elements.
// @dev Pointer from an tuple id in the order_book to the refering tuple (price, order_ref).
// @param tuple_id The tuple_id.
// @return return the coresponding tuple containing a price and an order reference.
// @custom: Its mostly for optimization purposes. Store 1 element per day instead of two as one period has the same values every day.
@storage_var
func tuple_ref(tuple_id: felt) -> (price_x_order_ref_x_address: (felt, felt, felt)) {
}

// @notice Counter of the total tuples created.
// @dev Used for incrementing the tuple_ref storage variable.
// @return Current tuple_ref thats need to be incremented by one before assigning to an tuple(price, order). 
@storage_var
func tuple_ctr() -> (ctr: felt) {
}

@storage_var
func daily_rate(day: felt) -> (rate: felt) {
}


@view
func get_last_filled_day{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt) -> (day: felt) {
    let (get_day) = last_filled_day.read(user);
    return (day=get_day);
}

//updates the last day only if it is strictly superior, bridge side then the user can't withdraw the YT before that date.
@external
func set_last_filled_day{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt, day: felt) {
    let (get_day) = last_filled_day.read(user);
    let day_le = is_le(day, get_day); 
    if (day_le == 0){
        last_filled_day.write(user, day);  
        return();
    }
    return();  
}

// @notice Gets the order using the corresponding reference.
// @dev getter for the Order struct.
// @param _order_ref the reference of the order assigned to when creating an order.
// @return The user's order
@view
func get_order_with_ref{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_order_ref: felt, user: felt) -> (user_order: Order) {
    let (get_order) = order_ref.read(user, _order_ref);
    return (user_order=get_order);
}

// @notice Gets the number of orders for a certain day.
// @dev Used know more for debugging purposes, but later the counter storage var will probably be deleted 
// as it requires more storgae when an iteration over the day could be cheaper. 
// @param _day: Day in the order_book
// @return The number of placed orders for the day.
@view
func get_n_orders_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt,dir: felt) -> (n_orders: felt){
    let (n_orders) = get_next_slot_on_day(_day,1,dir);
    return (n_orders=n_orders-1);
}

// @notice Gets an order using the index for the day in the order_book.
// @dev getter used mostly for debugging and testing.
// @param _i: Iterator. 1 is the first element.
// @param _day: Day in the order book.
// @return The corresponding tuple (price, order_ref).
@view
func get_order_i_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_i: felt, _day: felt, dir: felt) -> (price_x_order_ref_x_address: (felt, felt, felt)){
    if (dir == 1){
        let (day_order) = order_book_s.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    } else {
        let (day_order) = order_book_b.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    }
    let (tuple) = tuple_ref.read(day_order[0]);
    return (price_x_order_ref_x_address = tuple);
}

// @notice Gets the amount of YT available for a certain order on a precise day.
// @dev Getter used mostly for debugging and testing.
// @param _i: Iterator. 1 is the first element.
// @param _day: Day in the order book.
// @param dir: Boolean determining to look in the buying/selling order book.
// @return The corresponding tuple (price, order_ref).
@view
func get_order_i_amount_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_i: felt, _day: felt, dir: felt) -> (amount: felt){
    if (dir == 1){
        let (day_order) = order_book_s.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    } else {
        let (day_order) = order_book_b.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    }
    return (amount = day_order[1]);
}

// @notice Creates and places an order.
// @dev This function probably won't be used as there is no need to place an order without checking the order book.
// @param amount: Amount of corresponding YT's the user whishes to sell/buy for the period.
// @param price: The price in underlying.
// @param direction: 1 = selling order, 0 = buying order.
// @param start_date: Start of the period in seconds from unix. 
// @param end_date: End of the period (the day starting this timestamp is included). 
@external    
func create_order{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}( // ~87k gas for storing 30days
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt,
) {
    alloc_locals;

    //timestamp not woriking in protostar, lets hardcode it
    //let (timestamp) = get_block_timestamp();
    let timestamp = 1686039304;


    // //Checks (for easier test lets skip some checks for now)
    // with_attr error_message(
    //         "amount and price must be non negative.") {
    //     assert_nn(_amount);
    //     assert_nn(_price);
    // }

    // with_attr error_message(
    //         "Given amount and price must be non zero.") {
    //     assert_not_zero(_amount);
    //     assert_not_zero(_price);    
    // }

    // let (check_start) = check_day_00(_start_date);
    // let (check_end) = check_day_00(_end_date);
    // with_attr error_message(
    //        "Timestamps must start at 00 for the following day.") {
    //     assert check_start = 1;
    //     assert check_end = 1;
    // }

    with_attr error_message(
            "start_date must be before end date") {
        assert_nn(_end_date-_start_date);
    }

    // with_attr error_message(
    //         "start_date must be after today") {
    //     assert_nn(timestamp - _start_date);
    //     assert_not_zero(timestamp - _start_date);
    // }

    

    let (caller_address) = get_caller_address();

    tempvar order: Order = Order(amount=_amount, price=_price, direction=_direction, active=1, start_date=_start_date, end_date=_end_date);  
    let (current_ctr_order_ref) = order_ref_ctr.read(caller_address);
    order_ref_ctr.write(caller_address, current_ctr_order_ref + 1); // increment the order reference
    order_ref.write(caller_address, current_ctr_order_ref + 1,order); // store the order struct

    //The ref to the order is stored now storing the price and ref in the order book
    //For each day store the tuple (price, id)
    let (n_days, _) = unsigned_div_rem((_end_date - _start_date), DAY);     
    
    let (current_tuple_ctr) = tuple_ctr.read();
    tuple_ctr.write(current_tuple_ctr + 1); //increment the tuple reference
    tuple_ref.write((current_tuple_ctr + 1), (_price, current_ctr_order_ref + 1, caller_address)); //store (price, order reference)
    
    fill_order_book(_current_date=_start_date, _n_days=(n_days+1), _tuple_ref=(current_tuple_ctr + 1), order_amount = _amount, dir = _direction); //30k gas (fill the order book for each day)
    return();
}

// @notice Internal function that fills the order_book storage var.
// @dev recursive function that increments the current day each call.
// @param _current_date: Current day timestamp.
// @param _n_days: number of days left to fill.
// @param _tuple_ref: Reference to the tuple (price, order ref, caller_address).
// @param order_amount: Amount of YT's the user wishes to buy/sell.
func fill_order_book{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_current_date: felt ,_n_days: felt, _tuple_ref: felt, order_amount: felt, dir: felt){
    if (_n_days==0){
        return();
    }
    //update mapping: date->list(order_tuples)
    if (dir == 1){
    let (next_order_book_slot) = get_next_slot_on_day(_day = _current_date, _i = 1, dir = 1);    
    order_book_s.write(_current_date, next_order_book_slot, (_tuple_ref, order_amount)); //update order book for each day (tuple ref, amount)
    tempvar syscall_ptr = syscall_ptr;
    } else {
    let (next_order_book_slot) = get_next_slot_on_day(_day = _current_date, _i = 1, dir = 0);    
    order_book_b.write(_current_date, next_order_book_slot, (_tuple_ref, order_amount)); //update order book for each day (tuple ref, amount)
    tempvar syscall_ptr = syscall_ptr;
    }

    //call recursion
    fill_order_book(_current_date + DAY, _n_days - 1, _tuple_ref, order_amount, dir = dir);
    return();
}


// @notice Creates and places an order, fills(matches and fills the orders) if possible.
// @dev Most important function of the contract.
// @param amount: Amount of corresponding YT's the user whishes to sell/buy for the period.
// @param price: The price in underlying.
// @param direction: 1 = selling order, 0 = buying order.
// @param start_date: Start of the period in seconds from unix. 
// @param end_date: End of the period (the day starting this timestamp is included). 
@external
func create_and_fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt,
) {
    alloc_locals;
    let (caller_address) = get_caller_address();
    tempvar order: Order = Order(amount=_amount, price=_price, direction=_direction, active=1, start_date=_start_date, end_date=_end_date);
    let (current_ctr_order_ref) = order_ref_ctr.read(caller_address);
    order_ref_ctr.write(caller_address, current_ctr_order_ref + 1); // increment the order reference
    order_ref.write(caller_address, current_ctr_order_ref + 1,order); // store the order struct

    let (n_days, _) = unsigned_div_rem((_end_date - _start_date), DAY);     

    let (current_tuple_ctr) = tuple_ctr.read();
    tuple_ctr.write(current_tuple_ctr + 1); //increment the tuple reference
    tuple_ref.write((current_tuple_ctr + 1), (_price, current_ctr_order_ref + 1, caller_address)); //store (price, order reference)
    
    //If we are placing a selling order
    if (_direction == 1){
        let (bridge_contract_address) = bridge_address.read();
        let (user_YT_balance) = Ibridge_l2.get_user_balance_YT(bridge_contract_address, caller_address);
        //verify no double spending
        assert_amount(_start_date, _end_date, user_YT_balance, caller_address);
        fill_order_book_and_fill_b(_current_date=_start_date, _n_days=(n_days+1), _tuple_ref=(current_tuple_ctr + 1), order_amount = _amount, price = _price); 
    } else {
        fill_order_book_and_fill_s(_current_date=_start_date, _n_days=(n_days+1), _tuple_ref=(current_tuple_ctr + 1), order_amount = _amount, price = _price); 
    }
    return();

}

//Identical to create and fill exept we don't need to check amount of YT's because its used for reselling yield
@external
func create_and_fill_no_check{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt,
) {
    alloc_locals;
    let (caller_address) = get_caller_address();
    tempvar order: Order = Order(amount=_amount, price=_price, direction=_direction, active=1, start_date=_start_date, end_date=_end_date);
    let (current_ctr_order_ref) = order_ref_ctr.read(caller_address);
    order_ref_ctr.write(caller_address, current_ctr_order_ref + 1); // increment the order reference
    order_ref.write(caller_address, current_ctr_order_ref + 1,order); // store the order struct

    let (n_days, _) = unsigned_div_rem((_end_date - _start_date), DAY);     

    let (current_tuple_ctr) = tuple_ctr.read();
    tuple_ctr.write(current_tuple_ctr + 1); //increment the tuple reference
    tuple_ref.write((current_tuple_ctr + 1), (_price, current_ctr_order_ref + 1, caller_address)); //store (price, order reference)
    
    //If we are placing a selling order
    if (_direction == 1){
        let (bridge_contract_address) = bridge_address.read();
        let (user_YT_balance) = Ibridge_l2.get_user_balance_YT(bridge_contract_address, caller_address);
        //no need to verify no double spending YT's because it is used only in a context of resell yield
        fill_order_book_and_fill_b(_current_date=_start_date, _n_days=(n_days+1), _tuple_ref=(current_tuple_ctr + 1), order_amount = _amount, price = _price); 
    } else {
        fill_order_book_and_fill_s(_current_date=_start_date, _n_days=(n_days+1), _tuple_ref=(current_tuple_ctr + 1), order_amount = _amount, price = _price); 
    }
    return();

}


// @notice If we are creating a selling order, try to fill buying orders, if not, place selling order 
func fill_order_book_and_fill_b{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_current_date: felt ,_n_days: felt, _tuple_ref: felt, order_amount: felt, price: felt) {
    alloc_locals;

    if (_n_days==0){
        return();
    }
    //Try and fill the order before placing it.
    let (var) = fill_day_b(_amount_left = order_amount, _price = price, _day = _current_date);
    local amount_left = var;
    
    //update mapping: date->list(order_tuples)
    let (next_order_book_slot) = get_next_slot_on_day(_day = _current_date, _i = 1, dir = 1);    
    order_book_s.write(_current_date, next_order_book_slot, (_tuple_ref, amount_left));

    //call recursion for next day
    return fill_order_book_and_fill_b(_current_date + DAY, _n_days - 1, _tuple_ref, order_amount, price);
}

func fill_order_book_and_fill_s{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_current_date: felt ,_n_days: felt, _tuple_ref: felt, order_amount: felt, price: felt) {
    alloc_locals;

    if (_n_days==0){
        return();
    }
    //Try and fill the order before placing it.
    let (var) = fill_day_s(_amount_left = order_amount, _price = price, _day = _current_date);
    local amount_left = var;
    
    //update mapping: date->list(order_tuples)
    let (next_order_book_slot) = get_next_slot_on_day(_day = _current_date, _i = 1, dir = 0);    
    order_book_b.write(_current_date, next_order_book_slot, (_tuple_ref, amount_left));

    //call recursion for next day
    return fill_order_book_and_fill_s(_current_date + DAY, _n_days - 1, _tuple_ref, order_amount, price);
}

// @notice Getter for the next available index in the order book array.
// @dev Permits us to remove the counter for daily orders storage_var.
// @param _i: Iterator. By default should start at 1.
// @param _day: Day in the order book.
// @return Next available slot in the order book to store a new order.
func get_next_slot_on_day{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _i: felt, dir: felt) -> (last_index: felt){
    //Lets iterate over the values of the orders on that day and wait for a 0 value. 
    if (dir == 1){
        let (order) = order_book_s.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    } else {
        let (order) = order_book_b.read(_day, _i);
        tempvar syscall_ptr = syscall_ptr;
    } 

    if (order[0]==0){
        return(last_index = _i);
    }

    return get_next_slot_on_day(_day= _day, _i = (_i + 1), dir = dir);
}

// @notice Getter for the non null number of orders for a day.
// @dev returns the number of orders with amount > 0.
// @param _i: Iterator. Default value 1.
// @param _day: Day in the order book.
// @param _ctr: Counter of skipped orders. Default value 1.
// @return Number of orders ready to be filled.
func get_number_of_available_orders{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _i: felt, _ctr: felt, dir: felt) -> (n_orders: felt){
	if (dir == 1){
    let (order) = order_book_s.read(_day, _i);
    tempvar syscall_ptr = syscall_ptr;
    } else {
    let (order) = order_book_b.read(_day, _i);
    tempvar syscall_ptr = syscall_ptr;
    }
    
    if (order[0] == 0){
        return(n_orders = _i - _ctr);
    }
	if (order[1] == 0){
        return get_number_of_available_orders(_day = _day, _i = (_i + 1), _ctr = _ctr + 1, dir = dir);
    } 
    return get_number_of_available_orders(_day= _day, _i = (_i + 1), _ctr = _ctr, dir = dir);
}

//@notice Getter of the index of the order with the lowest price in the order book for a particular day.
//@dev Uses starkware's usort and find element functions that relly on hints. WARNING: CHECK THAT USORT RETURNS AN ORDERED ARRAY
//@param _day: Day in the order book.
//@return Index in the order book of the order with the current lowest price.

@view
func get_spot_for_min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt) -> (price_idx: felt){
    alloc_locals;

    let (price_array) = alloc();
    let (array_size) = get_number_of_available_orders(_day = _day, _i = 1, _ctr = 1, dir = 1);
    if (array_size == 0){
        return (price_idx = -1);
    }

    //We copy the content of the storage var and copy it to this array
    let (skipped) = fill_available_price_array_from_storage(_day = _day, ctr = 1, _i = 0, _new_array_len = array_size, _new_array = price_array);
    
    //Now lets extract the lowest price
    let (ordered_price_array) = alloc();

    let (_, ordered_price_array, _) = usort(input_len = array_size, input = price_array);
    let price_min = ordered_price_array[0]; 

    //we found our lowest price but we need to index in the order book:
    //let (min_price_index) = find_element(array_ptr = price_array, elm_size = 1, n_elms = array_size, key = price_min);
    let (n_orders) = get_n_orders_for(_day, 1);
    let (min_price_index) = get_i_for_price_s(_day, n_orders, price_min, 1);

    //The address relative to the first element of the array 
    return (price_idx = min_price_index); 
}

//@notice Getter of the index of the order with the given price in the selling order_book 
//@dev This function iterates on the order book from i=1 to i=n_orders.
//@param _day: Day in the order book.
//@param n_orders: Number of orders that are present in the order book
//@param p: Price we are looking for.
//@param i: Iterator starting by default at 1.
//@return Index in the order book of the order with the given price.
@view
func get_i_for_price_s{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, n_orders: felt, p: felt, i: felt) -> (idx: felt){

    let (order) = order_book_s.read(_day, i);
    if(order[1] == 0){
        return get_i_for_price_s(_day, n_orders, p, i + 1);
    }
    let tuple_reference = order[0];
    let (price_and_order_and_address) = tuple_ref.read(tuple_reference);
    if(price_and_order_and_address[0] == p)	{
        return(idx = i);
    }

    return get_i_for_price_s(_day, n_orders, p, i + 1);
    
}

//@notice Getter of the index of the order with the highest price in the buying order book for a particular day.
//@dev Similar to get_spot_min. Don't forget to add a verification that the array returned by usort is ordered.
//@param _day: Day in the order book.
//@return Index in the order book of the order with the current lowest price.
@view
func get_spot_for_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt) -> (price_idx: felt){
    alloc_locals;

    let (price_array) = alloc();
    let (array_size) = get_number_of_available_orders(_day = _day, _i = 1, _ctr = 1, dir = 0);
    if (array_size == 0){
        return (price_idx = -1);
    }

    //We copy the content of the storage var and copy it to this array
    let (skipped) = fill_available_price_array_from_storage_b(_day = _day, ctr = 1, _i = 0, _new_array_len = array_size, _new_array = price_array);
    
    //Now lets extract the lowest price
    local output_len;
    let (ordered_price_array) = alloc();

    let (output_len, ordered_price_array, _) = usort(input_len = array_size, input = price_array);
    let price_max = ordered_price_array[output_len-1];

    //lets get the index of the highest price.
    let (n_orders) = get_n_orders_for(_day, 0);
    let (max_price_index) = get_i_for_price_b(_day, n_orders, price_max, 1);
    
    //The address relative to the first element of the array 
    return (price_idx = max_price_index); 
}

//@notice Getter of the index of the order with the given price in the buying order_book 
//@dev This function is identical to the get_i_for_price only it is for the buying order book.
//@param _day: Day in the order book.
//@param n_orders: Number of orders that are present in the order book
//@param p: Price we are looking for.
//@param i: Iterator starting by default at 1.
//@return Index in the buying order book of the order with the given price.
@view
func get_i_for_price_b{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, n_orders: felt, p: felt, i: felt) -> (idx: felt){

    let (order) = order_book_b.read(_day, i);
    if(order[1] == 0){
        return get_i_for_price_b(_day, n_orders, p, i + 1);
    }
    let tuple_reference = order[0];
    let (price_and_order_and_address) = tuple_ref.read(tuple_reference);
    if(price_and_order_and_address[0] == p)	{
        return(idx = i);
    }

    return get_i_for_price_b(_day, n_orders, p, i + 1);
    
}



//@notice Fills a given array with the available orders in the selling order_book
//@dev Extracts the content of the order_book_s storage var  .
//@param _day: Day in the order book.
//@param ctr (index of storage array) = 1
//@param _i(index of array to be filled) default = 0, 
//@param _new_array_len length of the array to be filled
//@param  _new_array pointer to the array to be filled. 
//@return Number of prices that were skipped.
func fill_available_price_array_from_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, ctr: felt, _i: felt, _new_array_len: felt, _new_array: felt*) -> (skipped_orders: felt){
    if (_i == _new_array_len){
        return(skipped_orders = ctr - 1 - _i);
    }
	let (order) = order_book_s.read(_day, ctr);
    if(order[1] != 0){
    	let tuple_reference = order[0];
    	let (price_and_order_and_address) = tuple_ref.read(tuple_reference);
    	//fill the new array
		assert _new_array[_i] = price_and_order_and_address[0];
		return fill_available_price_array_from_storage(_day = _day, ctr = (ctr + 1), _i = (_i + 1), _new_array_len = _new_array_len, _new_array = _new_array);

	}
    return fill_available_price_array_from_storage(_day = _day, ctr = (ctr + 1), _i = _i, _new_array_len = _new_array_len, _new_array = _new_array);
}

func fill_available_price_array_from_storage_b{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, ctr: felt, _i: felt, _new_array_len: felt, _new_array: felt*) -> (skipped_orders: felt){
    if (_i == _new_array_len){
        return(skipped_orders = ctr - 1 - _i);
    }
	let (order) = order_book_b.read(_day, ctr);
    if(order[1] != 0){
    	let tuple_reference = order[0];
    	let (price_and_order_and_address) = tuple_ref.read(tuple_reference);
    	//fill the new array
		assert _new_array[_i] = price_and_order_and_address[0];
		return fill_available_price_array_from_storage_b(_day = _day, ctr = (ctr + 1), _i = (_i + 1), _new_array_len = _new_array_len, _new_array = _new_array);

	}
    return fill_available_price_array_from_storage_b(_day = _day, ctr = (ctr + 1), _i = _i, _new_array_len = _new_array_len, _new_array = _new_array);
}

// @notice Searches the order book for that period an fills orders if possible.
// @dev This function does the same as create_and_fill function except that it doesn't
// @param amount: Amount of corresponding YT's the user whishes to sell/buy for the period.
// @param price: The price in underlying.
// @param direction: 1 = selling order, 0 = buying order.
// @param start_date: Start of the period in seconds from unix. 
// @param end_date: End of the period (the day starting this timestamp is included). 
@external
func fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt,
) { 
    if(_direction == 0){
    let (left) = fill_day_s(_amount, _price, _start_date);
    } else {
    let (left) = fill_day_b(_amount, _price, _start_date);
    }

    if(_end_date - _start_date != 0){ 
        return fill(_amount, _price, _direction, _start_date + DAY, _end_date);
    }
    return();
}

// @notice Searches for compatible selling orders on a day and fills them if possible.
// @dev This function updates the user's balances.
// @param amount_left: Amount of YT's left to fill for that day
// @param price: The maximum price of the selling orders we search for. 
// @param day: day in the order book.
// @return left: Amount of YT that was not matched (mostly for debuging as an order is created for this amount)
@external
func fill_day_s{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_amount_left: felt, _price: felt, _day: felt) -> (left: felt){
    alloc_locals;
    let (var) = get_caller_address();
    local caller_address = var;

    //get the index of the min price
    let (index_min_price) = get_spot_for_min(_day);
    if (index_min_price == -1){
        return(left = _amount_left); 
    }

    //fill the corresponding order
    //If price < _price, get the amount available and substract to update the order_book, else try again
    let (tuple_id_x_amount_available) = order_book_s.read(day = _day, idx = index_min_price);
    let (price_x_order_struct_x_address) = tuple_ref.read(tuple_id = tuple_id_x_amount_available[0]);
    let price_cmp = is_le(price_x_order_struct_x_address[0], _price);
    if (price_cmp == 1){
        //At least one order is compatible
        let amount_cmp =  is_le(_amount_left, tuple_id_x_amount_available[1]);
        //There is enough amount
        if (amount_cmp == 1){

            //Amount available = amount available - _amount
            order_book_s.write(_day, index_min_price, (tuple_id_x_amount_available[0], (tuple_id_x_amount_available[1] - _amount_left)));
            
            //Increment balance of buyer(caller)
            increment_balance(_day, caller_address, _amount_left);

            //Decrement Underlying(caller), maybe sum first and update at the end.
            //Contract address should be a const when initializing the contract.
            let (bridge_contract_address) = bridge_address.read();
            Ibridge_l2.decrement_balance_underlying(bridge_contract_address, caller_address, price_x_order_struct_x_address[0]*_amount_left);

            //increment Underlying(order_ref address)
            Ibridge_l2.increment_balance_underlying(bridge_contract_address, price_x_order_struct_x_address[2], price_x_order_struct_x_address[0]*_amount_left);

            return (left = 0);
        } 

        //There is not enough amount, fill and search for other price
        order_book_s.write(_day, index_min_price, (tuple_id_x_amount_available[0], 0));

        //increment balance of buyer(caller)
        increment_balance(_day, caller_address, tuple_id_x_amount_available[1]);

        //decrement Underlying(caller)
        let (bridge_contract_address) = bridge_address.read();
        Ibridge_l2.decrement_balance_underlying(bridge_contract_address, caller_address, price_x_order_struct_x_address[0]*tuple_id_x_amount_available[1]);

        //increment Underlying(order_ref address)
        Ibridge_l2.increment_balance_underlying(bridge_contract_address, price_x_order_struct_x_address[2], price_x_order_struct_x_address[0]*tuple_id_x_amount_available[1]);

        return fill_day_s(_amount_left - tuple_id_x_amount_available[1], _price, _day);
    }

    //there is no order for that price
    return(left = _amount_left);
}

//@notice Same as fill day s just searches and fills buying orders. Which means a seller is supposed to call it.
@external
func fill_day_b{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_amount_left: felt, _price: felt, _day: felt) -> (left: felt){
    alloc_locals;
    let (var) = get_caller_address();
    local caller_address = var;
    
    //get the index of the min price
    let (index_max_price) = get_spot_for_max(_day);
    if (index_max_price == -1){
        return(left = _amount_left); 
    }

    //fill the corresponding order
    //If price < _price, get the amount available and substract to update the order_book, else try again
    let (tuple_id_x_amount_available) = order_book_b.read(day = _day, idx = index_max_price);
    let (price_x_order_struct_x_address) = tuple_ref.read(tuple_id = tuple_id_x_amount_available[0]);
    let price_cmp = is_le(_price, price_x_order_struct_x_address[0]);
    if (price_cmp == 1){
        //At least one order is compatible
        let amount_cmp =  is_le(_amount_left, tuple_id_x_amount_available[1]);
        //There is enough amount
        if (amount_cmp == 1){  
            //amount available = amount available - _amunt
            order_book_b.write(_day, index_max_price, (tuple_id_x_amount_available[0], (tuple_id_x_amount_available[1] - _amount_left)));
          
            //increment user's balance(order's)
            increment_balance(_day, price_x_order_struct_x_address[2], _amount_left);

            //decrement Underlying(order address)
            let (bridge_contract_address) = bridge_address.read();
            Ibridge_l2.decrement_balance_underlying(bridge_contract_address, price_x_order_struct_x_address[2], price_x_order_struct_x_address[0]*_amount_left);

            //increment Underlying(caller)
            Ibridge_l2.increment_balance_underlying(bridge_contract_address, caller_address, price_x_order_struct_x_address[0]*_amount_left);

            return (left = 0);
        } 
        //There is not enough amount, fill and search for other price
        order_book_b.write(_day, index_max_price, (tuple_id_x_amount_available[0], 0));
      
        //increment user's balance(order's)
        increment_balance(_day, price_x_order_struct_x_address[2], tuple_id_x_amount_available[1]);

        //decrement Underlying(order address)
        let (bridge_contract_address) = bridge_address.read();
        Ibridge_l2.decrement_balance_underlying(bridge_contract_address, price_x_order_struct_x_address[2], price_x_order_struct_x_address[0]*tuple_id_x_amount_available[1]);

        //increment Underlying(caller)
        Ibridge_l2.increment_balance_underlying(bridge_contract_address, caller_address, price_x_order_struct_x_address[0]*tuple_id_x_amount_available[1]);

        return fill_day_b(_amount_left - tuple_id_x_amount_available[1], _price, _day);
    }

    //there is no order for that price
    return(left = _amount_left);
}


//@notice Getter of the user's YT balance for a precise day.
//@dev Mapping of the day and user address to the amount
//@param _day: Day in the order book.
//@param _user_address: user's address.
//@return balance: The user's balance.
@view
func get_user_balance_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _user_address: felt) -> (balance: felt) {
    let (amount) = user_balance.read(day = _day, user_address = _user_address);
    return (balance=amount);
}

//@notice Updates the user's YT balance for a precise day.
//@dev Only increments the balance, so we should add a check for nn values.
//@param _day: Day in the order book.
//@param _user_address: user's address.
//@return amount: The amount to add to the user's balance.
@external
func increment_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _user_address: felt, _amount: felt) {
    let (balance) = get_user_balance_for(_day, _user_address);
    user_balance.write(_day, _user_address, balance + _amount);  
    return();  
}

//@notice Updates the user's YT balance for a precise day.
//@dev Only decrements the balance symtetrically to increment balance.
//@param _day: Day in the order book.
//@param _user_address: user's address.
//@return amount: The amount to remove from the user's balance.
@external
func decrement_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _user_address: felt, _amount: felt) {
    let (balance) = get_user_balance_for(_day, _user_address);
    assert_nn(balance - _amount);
    user_balance.write(_day, _user_address, balance - _amount);  
    return();  
}

// Not used for now
@external
func resell_yield_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _price: felt, _amount: felt, user_address: felt) {
    let (balance) = get_user_balance_for(_day, user_address);
    assert_le(_amount, balance);
    decrement_balance(_day, user_address, _amount);
    create_and_fill(_amount, _price, 1, _day, _day);
    return();
}

@external
func resell_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(start_date: felt, end_date: felt, _price: felt, _amount: felt, user_address: felt) {
    decrement_available_resell_amount(start_date, end_date, _amount, user_address);

    create_and_fill_no_check(_amount, _price, 1, start_date, end_date);
    return();
}

func decrement_available_resell_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(start_date: felt, end_date: felt, _amount: felt, user_address: felt){
    if (start_date == end_date+DAY){
        return();
    }
    let (balance) = get_user_balance_for(start_date, user_address);
    assert_le(_amount, balance);    
    decrement_balance(start_date, user_address, _amount);

    return decrement_available_resell_amount(start_date + DAY, end_date, _amount, user_address);
}

//Calculates the sum of selling order amounts of YT's placed, for a day, for a user. 
@view
func sum_amount_YT_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(day: felt, user: felt, sum_amount: felt, n_orders: felt, i: felt)->(sum: felt){
    alloc_locals;

    if(i == n_orders+1){
        return(sum = sum_amount);
    }

    let (tuple_id_x_amount_available) = order_book_s.read(day, i);
    let (price_x_order_struct_x_address) = tuple_ref.read(tuple_id = tuple_id_x_amount_available[0]);

    if(price_x_order_struct_x_address[2] == user){
        let (order) = get_order_with_ref(price_x_order_struct_x_address[1], user);
        let order_amount = order.amount;
        local new_amount;
        assert new_amount = sum_amount + order_amount;

        return sum_amount_YT_for(day, user, new_amount, n_orders, i+1);
    }
    return sum_amount_YT_for(day, user, sum_amount, n_orders, i+1);
}

//Asserts the amount of YT's placed in the order book in order to not allow double order placements, or more than available.
//Max amount is the user's YT balance.
@view
func assert_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(start_date: felt, end_date: felt, max_amount: felt, user: felt) {
    if(start_date == end_date+DAY){
        return();
    }

    let (n_orders_today) = get_n_orders_for(start_date, 1);
    let (sum_today) = sum_amount_YT_for(start_date, user, 0, n_orders_today, 1);
    //revert if sum<=max
    assert_le(sum_today, max_amount); 
    return assert_amount(start_date+DAY, end_date, max_amount, user);
}

//Checks if an user has active orders and returns the amount to block for withdrawal.
@view
func YT_amount_to_block{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt, today_date: felt, i: felt, ctr: felt) -> (amount: felt) {
    //get selling orders and check it exists after today.
    let (user_order) = get_order_with_ref(i, user);
    if(user_order.end_date == 0){
        return(amount=ctr);
    } 

    //If buying order, skip
    if (user_order.direction == 0){
        return YT_amount_to_block(user, today_date, i + 1, ctr);
    }

    //If the order's end date is after or = today, we check the amount to block and call recursion, else we skip.
    let order_is_after = is_le(today_date, user_order.end_date);
    if (order_is_after == 0){
        //we skip
        return YT_amount_to_block(user, today_date, i + 1, ctr);
    }

    return YT_amount_to_block(user, today_date, i + 1, ctr + user_order.amount);
}

//Checks if an user has active orders and returns the amount to block for withdrawal.
@view
func U_amount_to_block{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt, today_date: felt, i: felt, ctr: felt) -> (amount: felt) {
    //get buying orders and check it exists after today.
    let (user_order) = get_order_with_ref(i, user);
    if(user_order.end_date == 0){
        return(amount=ctr);
    } 

    //If buying order, skip
    if (user_order.direction == 1){
        return U_amount_to_block(user, today_date, i + 1, ctr);
    }

    //If the order's end date is after or = today, we check the amount to block and call recursion, else we skip.
    let order_is_after = is_le(today_date, user_order.end_date);
    if (order_is_after == 0){
        //we skip
        return U_amount_to_block(user, today_date, i + 1, ctr);
    }
    let order_period_s = user_order.end_date - today_date;
    let (q, r) = unsigned_div_rem(order_period_s, DAY);
    let order_period_d = q+1;
    return U_amount_to_block(user, today_date, i + 1, ctr + user_order.price*order_period_d*user_order.amount);
}
//Updates user's claimable yield balance.
//Today is the day before the function is called, recursion will last until today-1 day.
//Last day is incremented recursivley until its equal to today.
//Old yield amount its user s yield amount it ibt. 
@external
func update_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt, last_day: felt, today: felt, old_yield_amount: felt) { 
    alloc_locals;

    if(last_day == today+DAY){
        //update storage
        claimable_yield.write(user, old_yield_amount);
        return();
    }

    //Get the amount, the rates(period for same amount), calculate new yield, call next update
    let (YT_amount) = get_user_balance_for(last_day, user);
    let (amount_x_period) = count_YT_period(last_day, today, 0, YT_amount, user);
    //let next_YT_amount = amount_x_period[0];
    let period = amount_x_period[1];

    //if amount = 0, skip
    if(YT_amount == 0){
        return update_yield(user, last_day + period*DAY, today, old_yield_amount);
    }

    //else compute new yield and call next recursion
    let (old_rate) = daily_rate.read(last_day);
    let (new_rate) = daily_rate.read(last_day + period*DAY);

    let (new_yield) = compute_yield(old_rate, new_rate, YT_amount, old_yield_amount);

    return update_yield(user, last_day + period*DAY, today, new_yield);
}

//counts how much YT's the user owns from last update to today.
//returns the period od that yt amount and the next amount
@view
func count_YT_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(last_day: felt, max_day: felt, ctr: felt, _amount: felt, user: felt) -> (res: (felt, felt)) {
    if (last_day == max_day+DAY){
        let amount_x_duration = (_amount, ctr);
        return(res = amount_x_duration);
    }

    let (day_amount) = get_user_balance_for(last_day, user);

    //If amount is the same, continue, else stop.
    if(day_amount == _amount){
        return count_YT_period(last_day+DAY, max_day, ctr+1, _amount, user);
    }

    let amount_x_duration = (day_amount, ctr);

    return(res = amount_x_duration);
}

@view
func compute_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(old_rate: felt, new_rate: felt, YT_amount: felt, old_yield_amount: felt) -> (res: felt){
    
    let YT_amount_mult = YT_amount*1000;
    let (YT_in_IBT, _) = unsigned_div_rem(YT_amount_mult,old_rate);

    let yield = YT_in_IBT*(new_rate-old_rate);
    
    let (yield_in_IBT, _) = unsigned_div_rem(yield,new_rate); 
    
    
    return (res= yield_in_IBT + old_yield_amount);
}


@external
func set_rate{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(day: felt, rate: felt) {
    daily_rate.write(day, rate);
    return();
}

@view
func get_user_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt) -> (yield: felt) {
    let (user_yield) = claimable_yield.read(user);
    return(yield=user_yield);
}


//USED IN BRIDGE

//Computes each day the user's non belonging amount of yt, connects a period if possible for yield computation
//Again today should be today - 1 as we would need tomorrow's rate in order to compute the yield of today
@view
func compute_non_belonging_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user: felt, last_date: felt, today: felt, yield_sum: felt) -> (yield: felt){
    alloc_locals;

    if (last_date == today + DAY){
        return (yield = yield_sum);
    }

    let (n_orders) = get_n_orders_for(last_date, 1);
    //Get nb YT's for that user's day
    let (nb_YT) = get_nb_YT_for(last_date, user, 0, n_orders, 1);

    //Get the period duration
    let (amount_period) = get_nb_period(last_date, today, 0, nb_YT, user);

    //Compute yield and call recursion (If amount == 0 skip)
    if(nb_YT == 0){
        return compute_non_belonging_yield(user, last_date + amount_period*DAY, today, yield_sum);
    }

    let (old_rate) = daily_rate.read(last_date);
    let (new_rate) = daily_rate.read(last_date + amount_period*DAY);

    let (new_yield) = compute_yield(old_rate, new_rate, nb_YT, 0);
    
    
    return compute_non_belonging_yield(user, last_date + amount_period*DAY, today, yield_sum + new_yield);
}

//returns the amount of nb YT's for a certain day
@view
func get_nb_YT_for{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(day: felt, user: felt, sum_amount: felt, n_orders: felt, i: felt) -> (amount: felt){
    alloc_locals;

    if(i == n_orders+1){
        return(amount = sum_amount);
    }

    let (tuple_id_x_amount_available) = order_book_s.read(day, i);
    let (price_x_order_struct_x_address) = tuple_ref.read(tuple_id = tuple_id_x_amount_available[0]);

    if(price_x_order_struct_x_address[2] == user){
        let (order) = get_order_with_ref(price_x_order_struct_x_address[1], user);
        let max_amount = order.amount;
        let nb_amount = max_amount - tuple_id_x_amount_available[1];

        local new_amount;
        assert new_amount = sum_amount + nb_amount;

        return get_nb_YT_for(day, user, new_amount, n_orders, i+1);
    }
    return get_nb_YT_for(day, user, sum_amount, n_orders, i+1);
}

@view
func get_nb_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(last_day: felt, max_day: felt, ctr: felt, _amount: felt, user: felt) -> (res: felt){
    if (last_day == max_day+DAY){
        return(res = ctr);
    }

    let (n_orders) = get_n_orders_for(last_day, 1);
    let (day_amount) = get_nb_YT_for(last_day, user, 0, n_orders, 1);

    //If amount is the same, continue, else stop.
    if(day_amount == _amount){
        return get_nb_period(last_day+DAY, max_day, ctr+1, _amount, user);
    }

    return(res=ctr);
}