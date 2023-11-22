%lang starknet

from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.math import assert_lt_felt, assert_not_zero, assert_nn
from starkware.starknet.common.eth_utils import assert_eth_address_range
from starkware.starknet.common.messages import send_message_to_l1
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.math import unsigned_div_rem
//not working in protostar
from starkware.starknet.common.syscalls import get_block_timestamp

//Number of seconds in a day
const DAY = 86400;

//ID's for the message sent to L1
const WITHDRAW_U= 0;
const WITHDRAW_YT= 1;

////Events
@event
func deposit_caller(address: felt, amount: felt) {
}

@contract_interface
namespace Iorder_book {
    func compute_non_belonging_yield(user: felt, last_date: felt, today: felt, yield_sum: felt) -> (yield: felt){
    }

    func YT_amount_to_block(user: felt, today_date: felt, i: felt, highest_amount: felt) -> (amount: felt) {
    }

    func U_amount_to_block(user: felt, today_date: felt, i: felt, highest_amount: felt) -> (amount: felt) {
    }
}

////storage_vars

//Bool that will be used to check if a bridge has been initialized.
@storage_var
func initialized() -> (bool: felt) {
}

//Variable that stores the governor of the bridge.
@storage_var
func governor() -> (address: felt) {
}

@storage_var
func l1_bridge_address() -> (address: felt) {
}

@storage_var
func user_balance_underlying(user_address: felt) -> (res: felt) {
}

//The following could be packed into one var potentialy
@storage_var
func user_claimable_yield(user_address: felt) -> (amount: felt) {
}

@storage_var
func user_balance_YT(user_address: felt) -> (amount: felt) {
}

@storage_var
func user_last_update(user_address: felt) -> (date: felt) {
}

@storage_var
func order_book_contract() -> (address: felt) {
}


////getters

//This function gets the address of the caller as in protostar there is no command to retrieve it and it is different in every call.
//It's only used for test purposes and will be removed.
@view
func test_get_caller{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (res: felt) {
    let (caller) = get_caller_address();
    return(res = caller);
}

@view
func get_initialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (bool: felt) {
    let (res) = initialized.read();
    return (bool=res);
}

@view
func get_governor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    let (res) = governor.read();
    return (address=res);
}

@view
func get_l1_bridge{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (address: felt) {
    let (res) = l1_bridge_address.read();
    return (address=res);
}

@view
func get_user_balance_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_user_address: felt) -> (balance: felt) {
    let (amount) = user_balance_underlying.read(user_address = _user_address);
    return (balance=amount);
}

@view
func get_user_balance_YT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_user_address: felt) -> (balance: felt) {
    let (amount) = user_balance_YT.read(user_address = _user_address);
    return (balance=amount);
}

@view
func get_user_claimable_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_user_address: felt) -> (balance: felt) {
    let (amount) = user_claimable_yield.read(user_address = _user_address);
    return (balance=amount);
}

@view
func get_user_last_update{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(user_address: felt) -> (date: felt){
    let (last_update) = user_last_update.read(user_address);
    return (date = last_update);
}



////modifiers

func only_uninitialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    let (is_initialized: felt) = get_initialized();
    with_attr error_message("The contract was already initialized") {
        assert is_initialized = 0;
    }
    return ();
}

func only_governor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    // The call is restricted to the governor.
    let (caller_address) = get_caller_address();
    let (governor_address) = get_governor();
    with_attr error_message("The caller must be the governor of the function") {
        assert caller_address = governor_address;
    }
    return ();
}

/////Internal functions

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

//Updates the storage variable is_initialized to true if possible
func set_initialized{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    //Modifier
    only_uninitialized();
    //Set the bool to initialized
    initialized.write(1);
    return ();
}

//@notice Simply increment the user's Underlying balance.
//@dev The caller must be the contract or the order book contract.
@external
func increment_balance_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_user_address: felt, _amount: felt) {
    let (balance) = get_user_balance_underlying( _user_address);
    user_balance_underlying.write(_user_address, balance + _amount);  
    return();  
}

//@notice Simply decrement the user's Underlying balance
@external
func decrement_balance_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_user_address: felt, _amount: felt) {
    let (balance) = get_user_balance_underlying(_user_address);
    assert_nn(balance - _amount);
    user_balance_underlying.write(_user_address, balance - _amount);  
    return();  
}

//@notice Function that updates the user's yield balance.
//@dev It takes for now rates as parameters before we integrate the rate Oracle. 
func update_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(old_rate: felt ,new_rate: felt, user: felt){
    alloc_locals;

    //Get old yield balance and current YT balance
    let (old_yield) = get_user_claimable_yield(user);
    let (YT_balance) = get_user_balance_YT(user);
    let (test_last_date_updated) = user_last_update.read(user);
    local decider;

    if (test_last_date_updated == 0){
        decider = 1;
    } else {
        decider = 0;
    }

    //First should be the day of deployemnt (or at least a closer date than 1970).
    let last_date_updated = test_last_date_updated + 1654128000 * decider;
    let (assert_date) = check_day_00(last_date_updated);
    assert assert_date = 1;

    //Get today's date.
    //let (timestamp) = get_block_timestamp();
    //Temporary fix.
    let timestamp = 1686039304;
    //timestamp - r probably
    let (q, r) = unsigned_div_rem(timestamp, DAY);
    let date = timestamp-r;

    //Compute yield
    let YT_amount_mult = YT_balance*1000;
    let (YT_in_IBT, _) = unsigned_div_rem(YT_amount_mult,old_rate);

    let yield = YT_in_IBT*(new_rate-old_rate);
    
    let (yield_in_IBT, _) = unsigned_div_rem(yield,new_rate); 
    
    //total yield, we need to subtract the yield not belonging 
    let total_new_yield = yield_in_IBT + old_yield;

    let (order_book) = order_book_contract.read();
    let (not_belonging_yield) = Iorder_book.compute_non_belonging_yield(order_book, user, last_date_updated, date, 0);

    let new_yield = total_new_yield - not_belonging_yield;


    //Update yield
    user_claimable_yield.write(user, new_yield);

    //Update last date
    user_last_update.write(user, date);
    
    return();
}


////external functions

@external
func initialize{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    init_array_len: felt, init_array: felt*
) {
    set_initialized();
    with_attr error_message("address only is in the array") {
        assert init_array_len = 1;
    }
    let governor_address = [init_array];
    with_attr error_message("The address must not be 0") {
        assert_not_zero(governor_address);
    }
    //Set the address of the governor
    governor.write(governor_address);
    return ();
}

@external
func set_l1_bridge{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    //only_governor modifier
    only_governor();

    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("The bridge was already set") {
        assert l1_bridge = 0;
    }

    with_attr error_message("Not an eth address") {
        assert_eth_address_range(address);
    }

    //Set new value
    l1_bridge_address.write(address);
    return ();
}

@external
func set_order_book_contract{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(address: felt) {
    //only_governor modifier
    only_governor();
    order_book_contract.write(address);
    return();
}

//@notice Initiates the withdrawal of Underlying.
//@dev It sends a message to the L1 bridge.
//@param l1_recipient: Address of the user on L1 the funds are to be sent to (User's L1 address).
//@param amount: Amount of Underlying to bridge.
//@custom We should use Uint256 for the amounts probably.
@external
func initiate_withdraw_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(l1_recipient: felt, amount: felt) {
    alloc_locals;

    with_attr error_message("INVALID_L1_ADDRESS") {
        assert_eth_address_range(l1_recipient);
    }

    with_attr error_message("INVALID_AMOUNT") {
        assert_nn(amount);
    }

    with_attr error_message("ZERO_WITHDRAWAL") {
        assert_not_zero(amount);
    }

    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("UNINITIALIZED_L1_BRIDGE_ADDRESS") {
        assert_not_zero(l1_bridge);
    }


    let (order_book_address) = order_book_contract.read();

    let (caller_address) = get_caller_address();    
    let (balance_before) = get_user_balance_underlying(caller_address);

    //Harcode timestamp for protostar quick fix
    //let (timestamp) = get_block_timestamp();
    let timestamp = 1686039304;
    let (q, r) = unsigned_div_rem(timestamp, DAY);
    let time_today = q*DAY; 
    //The user's YT cannot be withdrawn before end_date of his order that has been filled.
    let (block_amount) = Iorder_book.U_amount_to_block(order_book_address, caller_address, time_today, 1, 0);


    with_attr error_message("INSUFFICIENT_FUNDS") {
        assert_nn(balance_before - amount - block_amount);
    }

    decrement_balance_underlying(caller_address, amount);

    // Send the message
    let (message_payload: felt*) = alloc();
    assert message_payload[0] = WITHDRAW_U; //withdraw message
    assert message_payload[1] = l1_recipient;
    assert message_payload[2] = amount;

    send_message_to_l1(to_address=l1_bridge, payload_size=3, payload=message_payload);

    //maybe emit an event
    return ();
}

//This function initiates the withdrawal of the yield from the Yield Market.
@external
func initiate_claim_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(l1_recipient: felt, amount: felt, old_rate: felt, new_rate: felt) {
    alloc_locals;


    with_attr error_message("INVALID_L1_ADDRESS") {
        assert_eth_address_range(l1_recipient);
    }

    with_attr error_message("INVALID_AMOUNT") {
        assert_nn(amount);
    }

    with_attr error_message("ZERO_WITHDRAWAL") {
        assert_not_zero(amount);
    }

    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("UNINITIALIZED_L1_BRIDGE_ADDRESS") {
        assert_not_zero(l1_bridge);
    }

    let (caller_address) = get_caller_address();    

    update_yield(old_rate, new_rate, caller_address);
    
    let (balance_before) = get_user_claimable_yield(caller_address);

    //Apply the fee on withdrawals if any but only check if there is enough, the fee will be charged on l1    
    //let currentFee = ((amount * yieldFee) / MAX_FEES); 
    //assert_nn(balance_before - amount - currentFee);

    with_attr error_message("INSUFFICIENT_FUNDS") {
        assert_nn(balance_before - amount);
    }

    //decrement yield balance
    local new_yield_balance = balance_before - amount;
    user_claimable_yield.write(caller_address, new_yield_balance);

    // Send the message
    let (message_payload: felt*) = alloc();
    assert message_payload[0] = 2; //claim message
    assert message_payload[1] = l1_recipient;
    assert message_payload[2] = amount;

    send_message_to_l1(to_address=l1_bridge, payload_size=3, payload=message_payload);
    return ();
}

//@notice Initiates the withdrawal of YT's.
//@dev It send a message to the L1 bridge.
//@param l1_recipient: Address of the user on L1 the funds are to be sent to.
//@param user: Starknet address of the account doing the bridge. 
//@param amount: Amount of Underlying to bridge.
@external
func initiate_withdraw_YT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(l1_recipient: felt, user: felt, amount: felt) {
    alloc_locals;

    with_attr error_message("INVALID_L1_ADDRESS") {
        assert_eth_address_range(l1_recipient);
    }

    with_attr error_message("INVALID_AMOUNT") {
        assert_nn(amount);
    }

    with_attr error_message("ZERO_WITHDRAWAL") {
        assert_not_zero(amount);
    }

    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("UNINITIALIZED_L1_BRIDGE_ADDRESS") {
        assert_not_zero(l1_bridge);
    }

    let (order_book_address) = order_book_contract.read();

    //Harcode timestamp for protostar quick fix
    //let (timestamp) = get_block_timestamp();
    let timestamp = 1686039304;
    let (q, r) = unsigned_div_rem(timestamp, DAY);
    let time_today = q*DAY; 
    //The user's YT cannot be withdrawn before end_date of his order that has been filled.
    let (block_amount) = Iorder_book.YT_amount_to_block(order_book_address, user, time_today, 1, 0);

    let caller_address = user;
    let (balance_before) = get_user_balance_YT(caller_address);
    with_attr error_message("INSUFFICIENT_FUNDS") {
        assert_nn(balance_before - amount - block_amount);
    }

    
    //Update YT balance
    let old_YT_balance = balance_before;
    local new_YT_balance = old_YT_balance - amount;
    user_balance_YT.write(caller_address, new_YT_balance);

    // Send the message
    let (message_payload: felt*) = alloc();
    assert message_payload[0] = WITHDRAW_YT; //withdraw message
    assert message_payload[1] = l1_recipient;
    assert message_payload[2] = amount;

    send_message_to_l1(to_address=l1_bridge, payload_size=3, payload=message_payload);

    //maybe emit an event
    return ();
}


//@notice This function reacts to a message received from the L1 indicating Underlying tokens have been deposited.
//@dev Simply increment user's balance.
//@param from_address: Address that called this function, should be the L1 bridge.
//@param account: L2 account that should recieve the funds.
//@param amount: Amount that was bridged. 
//@custom Often i see that functions also check wheater the amount changed was excpected.
@l1_handler
func handle_deposit_underlying{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, account: felt, amount: felt
) {
    alloc_locals;
    
    with_attr error_message("ZERO_ACCOUNT_ADDRESS") {
        assert_not_zero(account);
    }
    
    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("UNINITIALIZED_L1_BRIDGE_ADDRESS") {
        assert_not_zero(l1_bridge);
    }

    with_attr error_message("EXPECTED_FROM_BRIDGE_ONLY") {
        assert from_address = l1_bridge;
    }

    with_attr error_message("INVALID_AMOUNT") {
        assert_nn(amount);
        assert_not_zero(amount);
    }

    increment_balance_underlying(account, amount);

    return ();
}

//@custom Daily rate and old rate are for debugging only. Later it will be handled with the date and Rate Oracle. 
@l1_handler
func handle_deposit_YT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    from_address: felt, account: felt, amount: felt, date: felt, day_rate: felt, old_rate: felt
) {
    alloc_locals;
    
    with_attr error_message("ZERO_ACCOUNT_ADDRESS") {
        assert_not_zero(account);
    }
    let (l1_bridge) = get_l1_bridge();
    with_attr error_message("UNINITIALIZED_L1_BRIDGE_ADDRESS") {
        assert_not_zero(l1_bridge);
    }
    with_attr error_message("EXPECTED_FROM_BRIDGE_ONLY") {
        assert from_address = l1_bridge;
    }
    with_attr error_message("INVALID_AMOUNT") {
        assert_nn(amount);
        assert_not_zero(amount);
    }

    //update yield
    update_yield(old_rate, day_rate, account);

    //update YT balance
    let (old_YT_balance) = user_balance_YT.read(account);
    local new_YT_balance = old_YT_balance + amount;
    user_balance_YT.write(account, new_YT_balance);

    deposit_caller.emit(account, amount);

    return ();
}