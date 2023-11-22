%lang starknet

from src.order_book import Order
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import get_block_timestamp


//Note: The tests here are the external and view functions. They are good examples of how to use them. 
//The internal functions have also been tested but are commented below). 

@contract_interface
namespace order_book {

    func create_order(
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt
    ){
    }

    func get_order_with_ref(_order_ref: felt, user: felt) -> (user_order: Order) {
    }  

    func get_n_orders_for(_day: felt, dir: felt) -> (n_orders: felt){
    }

    func get_order_i_for(_i: felt, _day: felt, dir: felt) -> (price_x_order_ref_x_address: (felt, felt, felt)){
    }

    func get_element_at(input: felt, at: felt) -> (response: felt){
    }

    func set_element_at(input: felt, at: felt, element: felt) -> (response: felt){
    }

    func get_spot_for_min(_day: felt) -> (price: felt){
    }

    func fill(_amount: felt, _price: felt, _direction: felt, _start_date: felt, _end_date: felt){
    }

    func get_order_i_amount_for(_i: felt, _day: felt, dir: felt) -> (amount: felt){
    }

    func fill_day_s(_amount_left: felt, _price: felt, _day: felt) -> (left: felt){
    }

    func fill_day_b(_amount_left: felt, _price: felt, _day: felt) -> (left: felt){
    }

    func create_and_fill(
    _amount: felt,
    _price: felt,
    _direction: felt,
    _start_date: felt,
    _end_date: felt
    ){
    }

    func get_i_for_price_s(_day: felt, n_orders: felt, p: felt, i: felt) -> (idx: felt){
    }

    func get_spot_for_max(_day: felt) -> (price: felt){
    }

    func get_user_balance_for(_day: felt, _user_address: felt) -> (balance: felt) {
    }

    func increment_balance(_day: felt, _user_address: felt, _amount: felt) {
    }

    func decrement_balance(_day: felt, _user_address: felt, _amount: felt) {
    }

    func resell_yield(start_date: felt, end_date: felt, _price: felt, _amount: felt, user_address: felt) {
    }

    func sum_amount_YT_for(day: felt, user: felt, sum_amount: felt, n_orders: felt, i: felt)->(sum: felt){
    }

    func assert_amount(start_date: felt, end_date: felt, max_amount: felt, user: felt) {
    }

    func compute_yield(old_rate: felt, new_rate: felt, YT_amount: felt, old_yield_amount: felt) -> (res: felt){
    }

    func count_YT_period(last_day: felt, max_day: felt, ctr: felt, _amount: felt, user: felt) -> (res: (felt, felt)) {
    }

    func update_yield(user: felt, last_day: felt, today: felt, old_yield_amount: felt) { 
    }

    func set_rate(day: felt, rate: felt) {
    }

    func get_user_yield(user: felt) -> (yield: felt) {
    }

    func get_nb_YT_for(day: felt, user: felt, sum_amount: felt, n_orders: felt, i: felt) -> (amount: felt){
    }

    func get_nb_period(last_day: felt, max_day: felt, ctr: felt, _amount: felt, user: felt) -> (res: felt){
    }

    func compute_non_belonging_yield(user: felt, last_date: felt, today: felt, yield_sum: felt) -> (yield: felt){
    }

    func set_bridge(address: felt) {
    }

    func YT_amount_to_block(user: felt, today_date: felt, i: felt, highest_amount: felt) -> (amount: felt) {
    }

    func U_amount_to_block(user: felt, today_date: felt, i: felt, highest_amount: felt) -> (amount: felt) {
    }


}

@contract_interface
namespace bridge_l2 {
    func increment_balance_underlying(_user_address: felt, _amount: felt) {
    }

    func test_get_caller() -> (res: felt) {
    }

    func initialize(init_array_len: felt, init_array: felt*) {
    }

    func set_l1_bridge(address: felt) {
    }

    func get_l1_bridge() -> (address: felt) {
    }

    func set_order_book_contract(address: felt) {
    }
}


@external
func test_block_YT_U{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    local bridge_contract_address: felt;
    %{ ids.bridge_contract_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}

    //Initialize the bridge.
    let (this_address) = bridge_l2.test_get_caller(bridge_contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(bridge_contract_address ,input_len, input);

    bridge_l2.set_l1_bridge(bridge_contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(bridge_contract_address);

    bridge_l2.set_order_book_contract(bridge_contract_address, contract_address);
    
    order_book.set_bridge(contract_address, bridge_contract_address);

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693692000 + DAY;
    const SEPTEMBER_5 = 1693864800;
    const SEPTEMBER_6 = 1693864800 + DAY;
    const SEPTEMBER_7 = 1693864800 + DAY*2;

     //Lets fund the address that created the order
    bridge_l2.increment_balance_underlying(bridge_contract_address, this_address, 10000);
    %{ send_message_to_l2(fn_name="handle_deposit_YT",from_address=ids.l1_address ,to_address=ids.bridge_contract_address , payload=[ids.this_address, 1000, 86400, 2000, 1000]) %}

    // CONTRACT IS READY

    //Lets start by creating some orders
    order_book.create_and_fill(contract_address, _amount=200, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_6);
    order_book.create_and_fill(contract_address, _amount=100, _price=5, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_3);
    order_book.create_and_fill(contract_address, _amount=50, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_6);

    let (amount_test) = order_book.YT_amount_to_block(contract_address, this_address, SEPTEMBER_4, 1, 0);
    assert amount_test = 250;

    order_book.create_and_fill(contract_address, _amount=200, _price=6, _direction=0, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_6);
    order_book.create_and_fill(contract_address, _amount=100, _price=5, _direction=0, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_3);
    order_book.create_and_fill(contract_address, _amount=50, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_6);

    let (amount_test2) = order_book.U_amount_to_block(contract_address, this_address, SEPTEMBER_4, 1, 0);
    assert amount_test2 = 3600 + 600;

    return();

}

@external
func test_nb_YT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    local bridge_contract_address: felt;
    %{ ids.bridge_contract_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}

    //Initialize the bridge.
    let (this_address) = bridge_l2.test_get_caller(bridge_contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(bridge_contract_address ,input_len, input);

    bridge_l2.set_l1_bridge(bridge_contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(bridge_contract_address);

    bridge_l2.set_order_book_contract(bridge_contract_address, contract_address);
    
    order_book.set_bridge(contract_address, bridge_contract_address);

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693692000 + DAY;
    const SEPTEMBER_5 = 1693864800;
    const SEPTEMBER_6 = 1693864800 + DAY;
    const SEPTEMBER_7 = 1693864800 + DAY*2;

     //Lets fund the address that created the order
    bridge_l2.increment_balance_underlying(bridge_contract_address, this_address, 10000);
    %{ send_message_to_l2(fn_name="handle_deposit_YT",from_address=ids.l1_address ,to_address=ids.bridge_contract_address , payload=[ids.this_address, 1000, 86400, 2000, 1000]) %}

    //Placing 3 selling orders
    order_book.create_and_fill(contract_address, _amount=200, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    order_book.create_and_fill(contract_address, _amount=100, _price=5, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    order_book.create_and_fill(contract_address, _amount=50, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);

    let (day1_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 1);
    assert day1_order1 = 200; 

    //Lets fill them
    order_book.create_and_fill(contract_address, _amount=100, _price=5, _direction=0, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    
    let (day1_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3, dir = 1);
    assert day1_order3 = 0;
    let (day1_order2) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3, dir = 1);
    assert day1_order2 = 50;


    //test user's nn belonging s amount of YT's
    let (test1) = order_book.get_nb_YT_for(contract_address, SEPTEMBER_3, this_address, 0, 3, 1);
    assert test1 = 100;

    let (test2) = order_book.get_nb_period(contract_address, SEPTEMBER_6, SEPTEMBER_7, 0, 0, this_address);
    assert test2 = 2;


    //Test the compute yield function
    order_book.set_rate(contract_address, SEPTEMBER_3, 1000);
    order_book.set_rate(contract_address, SEPTEMBER_6, 1500);
    order_book.set_rate(contract_address, SEPTEMBER_7, 2000);
    order_book.create_and_fill(contract_address, _amount=100, _price=6, _direction=1, _start_date=SEPTEMBER_6, _end_date= SEPTEMBER_6);
    order_book.create_and_fill(contract_address, _amount=50, _price=6, _direction=0, _start_date=SEPTEMBER_6, _end_date= SEPTEMBER_6);
    
    let (test4) = order_book.compute_non_belonging_yield(contract_address, this_address, SEPTEMBER_3, SEPTEMBER_7 - DAY, 0);
    assert test4 = 41;

    return();
}

@external
func test_update_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    
    const ADDRESS1 = 0x123123;

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693692000 + DAY;
    const SEPTEMBER_5 = 1693864800;
    const SEPTEMBER_6 = 1693864800 + DAY;
    const SEPTEMBER_7 = 1693864800 + DAY*2;

    order_book.increment_balance(contract_address, SEPTEMBER_3, ADDRESS1, 1000);
    order_book.increment_balance(contract_address, SEPTEMBER_4, ADDRESS1, 0);
    order_book.increment_balance(contract_address, SEPTEMBER_5, ADDRESS1, 0);
    order_book.increment_balance(contract_address, SEPTEMBER_6, ADDRESS1, 100);
    order_book.increment_balance(contract_address, SEPTEMBER_7, ADDRESS1, 100);

    //Yield is multiplied by 1000 for decimal issue
    order_book.set_rate(contract_address, SEPTEMBER_3, 1000);
    order_book.set_rate(contract_address, SEPTEMBER_4, 1500);
    order_book.set_rate(contract_address, SEPTEMBER_6, 1500);
    order_book.set_rate(contract_address, SEPTEMBER_7, 2000);

    order_book.update_yield(contract_address, ADDRESS1, SEPTEMBER_3, SEPTEMBER_7 - DAY, 0);
    
    let (test_yield1) = order_book.get_user_yield(contract_address, ADDRESS1);
    //333 + 16
    assert test_yield1 = 349;
    
    return();
}

//Multiply all the parameters by 1000 for decimal issue.
@external
func test_compute_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    
    let (compute1) = order_book.compute_yield(contract_address, 1000, 1500, 100, 0);
    assert compute1 = 33;
    let (compute2) = order_book.compute_yield(contract_address, 1000, 2000, 100, 0);
    assert compute2 = 50;
    let (compute3) = order_book.compute_yield(contract_address, 1500, 2000, 100, 33);
    assert compute3 = 49;

    return();
}

@external
func test_count_YT_period{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    const ADDRESS1 = 0x123123;

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693692000 + DAY;
    const SEPTEMBER_5 = 1693864800;
    const SEPTEMBER_6 = 1693864800 + DAY;

    order_book.increment_balance(contract_address, SEPTEMBER_3, ADDRESS1, 0);
    order_book.increment_balance(contract_address, SEPTEMBER_4, ADDRESS1, 50);
    order_book.increment_balance(contract_address, SEPTEMBER_5, ADDRESS1, 50);
    order_book.increment_balance(contract_address, SEPTEMBER_6, ADDRESS1, 0);

    let (amount1) = order_book.get_user_balance_for(contract_address, SEPTEMBER_3, ADDRESS1);
    
    let (test1) = order_book.count_YT_period(contract_address, SEPTEMBER_3, SEPTEMBER_6, 0, amount1, ADDRESS1);
    assert test1[0] = 50;
    assert test1[1] = 1;

    let (test2) = order_book.count_YT_period(contract_address, SEPTEMBER_3 + test1[1]*DAY, SEPTEMBER_6, 0, test1[0], ADDRESS1);
    assert test2[0] = 0;
    assert test2[1] = 2;

    return();
}

@external
func test_check_yt_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_5 = 1693864800;
    order_book.create_order(contract_address, _amount=100, _price=7, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);

    let (tup) = order_book.get_order_i_for(contract_address, 1, SEPTEMBER_3,1);
    let address = tup[2];

    let (test_amount1) = order_book.sum_amount_YT_for(contract_address ,SEPTEMBER_3, address, 0, 3, 1);
    assert test_amount1 = 300;
    
    //The user that placed the order has 400YT's before placing a new order he must have sum+amount<=YT balance
    order_book.assert_amount(contract_address, SEPTEMBER_3, SEPTEMBER_5, 400-50, address);

    return();
}


@external
func test_resell_yield{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    local bridge_contract_address: felt;
    %{ ids.bridge_contract_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}

    //Initialize the bridge.
    let (this_address) = bridge_l2.test_get_caller(bridge_contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(bridge_contract_address ,input_len, input);

    bridge_l2.set_l1_bridge(bridge_contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(bridge_contract_address);

    bridge_l2.set_order_book_contract(bridge_contract_address, contract_address);
    
    order_book.set_bridge(contract_address, bridge_contract_address);

    const ADDRESS1 = 0x123123;
    const ADDRESS2 = 0x456456;

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693692000 + DAY;
    const SEPTEMBER_5 = 1693864800;

    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS1, 100);
    order_book.increment_balance(contract_address,SEPTEMBER_4, ADDRESS1, 100);
    order_book.increment_balance(contract_address,SEPTEMBER_5, ADDRESS1, 100);

    //Lets fund the address that will buy the order
    bridge_l2.increment_balance_underlying(bridge_contract_address, ADDRESS1, 10000);
    bridge_l2.increment_balance_underlying(bridge_contract_address, ADDRESS2, 10000);

    order_book.resell_yield(contract_address ,SEPTEMBER_3, SEPTEMBER_5, 5, 75, ADDRESS1);

    //Test the balance update
    let (test_user_balance) = order_book.get_user_balance_for(contract_address,SEPTEMBER_3, ADDRESS1);
    assert test_user_balance = 25;

    //Test that the order was created
    let (day1_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 1);
    assert day1_order1 = 75;
    let (day3_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_5, dir = 1);
    assert day3_order1 = 75;
    let (day4_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_5+DAY, dir = 1);
    assert day4_order1 = 0;

    //Lets add another user
    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS2, 200);
    order_book.increment_balance(contract_address,SEPTEMBER_4, ADDRESS2, 200);
    order_book.increment_balance(contract_address,SEPTEMBER_5, ADDRESS2, 200);

    //He wishes to sell only the first day
    order_book.resell_yield(contract_address ,SEPTEMBER_3, SEPTEMBER_3, 9, 33, ADDRESS2);

    //Test the balance update
    let (test_user_balance2) = order_book.get_user_balance_for(contract_address,SEPTEMBER_3, ADDRESS2);
    assert test_user_balance2 = 167;

    //Test that the order was created
    let (day1_order2) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3, dir = 1);
    assert day1_order2 = 33;
    let (day2_order2) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_4, dir = 1);
    assert day2_order2 = 0;

    return();
}    


@external
func test_increment_balance{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    const ADDRESS1 = 0x123123;
    const ADDRESS2 = 0x456456;

    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_5 = 1693864800;

    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS1, 100);
    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS2, 5);

    let (test_amount1) = order_book.get_user_balance_for(contract_address, SEPTEMBER_3, ADDRESS1);
    assert test_amount1 = 100;
    let (test_amount2) = order_book.get_user_balance_for(contract_address,SEPTEMBER_3, ADDRESS2);
    assert test_amount2 = 5;

    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS1, 100);
    order_book.increment_balance(contract_address,SEPTEMBER_3, ADDRESS2, 5);

    let (test_amount3) = order_book.get_user_balance_for(contract_address,SEPTEMBER_3, ADDRESS1);
    assert test_amount3 = 200;
    let (test_amount4) = order_book.get_user_balance_for(contract_address,SEPTEMBER_3, ADDRESS2);
    assert test_amount4 = 10;

    order_book.increment_balance(contract_address,SEPTEMBER_5, ADDRESS1, 100);
    let (test_amount5) = order_book.get_user_balance_for(contract_address,SEPTEMBER_5, ADDRESS1);
    assert test_amount5 = 100;
    
    //lets decrement
    order_book.decrement_balance(contract_address,SEPTEMBER_5, ADDRESS1, 45);
    let (test_amount6) = order_book.get_user_balance_for(contract_address,SEPTEMBER_5, ADDRESS1);
    assert test_amount6 = 55;
    
    return();
}

@external
func test_create_and_fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
    alloc_locals;


    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    local bridge_contract_address: felt;
    %{ ids.bridge_contract_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}

    //Initialize the bridge.
    let (this_address) = bridge_l2.test_get_caller(bridge_contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(bridge_contract_address ,input_len, input);

    bridge_l2.set_l1_bridge(bridge_contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(bridge_contract_address);

    bridge_l2.set_order_book_contract(bridge_contract_address, contract_address);
    
    order_book.set_bridge(contract_address, bridge_contract_address);
    
    const DAY = 86400;
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_5 = 1693864800;
    order_book.create_order(contract_address, _amount=100, _price=7, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=6, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    
    //Lets fund the address that created the order
    let (order) = order_book.get_order_i_for(contract_address, 1, SEPTEMBER_3, dir = 0);
    let caller_address = order[2];
    bridge_l2.increment_balance_underlying(bridge_contract_address, caller_address, 10000);

    //set the timestamp to the contracts
    //%{ stop_warp = warp(1685972534, ids.bridge_contract_address) %}
    %{ send_message_to_l2(fn_name="handle_deposit_YT",from_address=ids.l1_address ,to_address=ids.bridge_contract_address , payload=[ids.caller_address, 1000, 86400, 2000, 1000]) %}

    order_book.create_and_fill(contract_address, _amount=50, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    


    //VALIDATION
    let (day1_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 0);
    assert day1_order1 = 50;
    let (day1_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3, dir = 0);
    assert day1_order3 = 100;

    let (day2_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3+DAY, dir = 0);
    assert day2_order1 = 50;
    let (day2_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3+DAY, dir = 0);
    assert day2_order3 = 100;

    let (day3_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3+DAY*2, dir = 0);
    assert day3_order1 = 50;
    let (day3_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3+DAY*2, dir = 0);
    assert day3_order3 = 100;


    order_book.create_and_fill(contract_address, _amount=210, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    
    let (day1_order1_new) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 0);
    assert day1_order1_new = 0;
    let (day1_order2_new) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3, dir = 0);
    assert day1_order2_new = 0;
    //the order one is skipped for some reason
    let (posted_order) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3, dir = 1);
    assert posted_order = 60;

    //Lets check the balance:
    let (order2) = order_book.get_order_i_for(contract_address, 1, SEPTEMBER_3, dir = 1);
    let caller_address2 = order2[2];
    let (balance_user2) = order_book.get_user_balance_for(contract_address, SEPTEMBER_3, caller_address2);
    assert balance_user2 = 200;


    order_book.create_and_fill(contract_address, _amount=75, _price=6, _direction=0, _start_date=SEPTEMBER_3, _end_date= SEPTEMBER_5);
    let (day1_order4) = order_book.get_order_i_amount_for(contract_address, _i = 4, _day = SEPTEMBER_3, dir = 0);
    assert day1_order4 = 15;

    //Lets check the balances:
    let (balance_user1) = order_book.get_user_balance_for(contract_address, SEPTEMBER_3, caller_address2);
    assert balance_user1 = 60 + balance_user2; //(as the address of this contract is the same it seems)


    
    //When there is no order present
    order_book.create_and_fill(contract_address, _amount=100, _price=6, _direction=1, _start_date=DAY, _end_date= DAY*2);
    let (day0_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = DAY, dir = 1);
    assert day0_order1 = 100;

    order_book.create_and_fill(contract_address, _amount=200, _price=8, _direction=0, _start_date=DAY, _end_date= DAY*2);

    let (day0_order1_new) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = DAY, dir = 1);
    assert day0_order1_new = 0;
    let (posted_order2) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = DAY, dir = 0);
    assert posted_order2 = 100 ;
    
    return();
}

@external
func test_fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    const DAY = 86400;

    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    local bridge_contract_address: felt;
    %{ ids.bridge_contract_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}
    
    order_book.set_bridge(contract_address, bridge_contract_address);
    
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_5 = 1693864800;
    //creation of 4 selling orders
    order_book.create_order(contract_address, _amount=100, _price=7, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=10, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    //Only the first day
    order_book.create_order(contract_address, _amount=100, _price=1, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_3);
    
    //Lets fund the address that created the order
    let (order) = order_book.get_order_i_for(contract_address, 1, SEPTEMBER_3, dir = 1);
    let caller_address = order[2];
    bridge_l2.increment_balance_underlying(bridge_contract_address, caller_address, 10000);

    let (index_min_price) = order_book.get_spot_for_min(contract_address,SEPTEMBER_3);
    assert index_min_price = 4;

    //Lets fill the first two days(By placing a buying order basicaly): 
    order_book.fill(contract_address, _amount = 150, _price = 6, _direction = 0, _start_date = SEPTEMBER_3, _end_date = SEPTEMBER_3 + DAY);
 
    //VALIDATION

    let (day1_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 1);
    assert day1_order1 = 100;
    let (day1_order2) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3, dir = 1);
    assert day1_order2 = 60;
    let (day1_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3, dir = 1);
    assert day1_order3 = 0;
    let (day1_order4) = order_book.get_order_i_amount_for(contract_address, _i = 4, _day = SEPTEMBER_3, dir = 1);
    assert day1_order4 = 0;

    let (day2_order1) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3 + DAY, dir = 1);
    assert day2_order1 = 100;
    let (day2_order2) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3 + DAY, dir = 1);
    assert day2_order2 = 0;

    let (day3_order3) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3 + DAY*2, dir = 1);
    assert day3_order3 = 10;

    


    //Now lets test the other direction: 4 buying orders and we want to sell.
    order_book.create_order(contract_address, _amount=100, _price=7, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=100, _price=6, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    order_book.create_order(contract_address, _amount=10, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
    //Only the first day
    order_book.create_order(contract_address, _amount=100, _price=8, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_3);
    
    let (index_max_price) = order_book.get_spot_for_max(contract_address,SEPTEMBER_3);
    assert index_max_price = 4;

    //Lets fill the first two days
    order_book.fill(contract_address, _amount = 150, _price = 6, _direction = 1, _start_date = SEPTEMBER_3, _end_date = SEPTEMBER_3 + DAY);

    let (day1_order1b) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3, dir = 0 );
    assert day1_order1b = 50;
    let (day1_order3b) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3, dir = 0);
    assert day1_order3b = 10;
    let (day1_order4b) = order_book.get_order_i_amount_for(contract_address, _i = 4, _day = SEPTEMBER_3, dir = 0);
    assert day1_order4b = 0;

    let (day2_order1b) = order_book.get_order_i_amount_for(contract_address, _i = 1, _day = SEPTEMBER_3 + DAY, dir = 0);
    assert day2_order1b = 0;
    let (day2_order2b) = order_book.get_order_i_amount_for(contract_address, _i = 2, _day = SEPTEMBER_3 + DAY, dir = 0);
    assert day2_order2b = 50;

    let (day3_order3b) = order_book.get_order_i_amount_for(contract_address, _i = 3, _day = SEPTEMBER_3 + DAY*2, dir = 0);
    assert day3_order3b = 10;


    return();
}

@external
func test_bitpacking{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    
    let var1 = 15;
    let var2 = 35;
    let (packed_var1) = order_book.set_element_at(contract_address ,0, 0, var1);
    let (test_get1) = order_book.get_element_at(contract_address, packed_var1, 0);
    assert packed_var1 = test_get1; 

    return();
}

@external
func test_get_n_null_s_orders_after_elt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    const DAY = 86400;

    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    //Lets create 8 orders of for the duration of 2 days.
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693778400;
    order_book.create_order(contract_address, _amount=0, _price=7, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=2, _price=7, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=20, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=2, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);

    let (test_1) = order_book.get_i_for_price_s(contract_address, SEPTEMBER_3, 8, 4, 1);
    assert test_1 = 6;   
    return();  
}

@external
func test_creating_orders{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    const DAY = 86400;

    local contract_address: felt;

     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    //Lets create an order of for the duration of 7 days.
    order_book.create_order(contract_address, _amount=100, _price=2, _direction=1, _start_date=1638352800, _end_date=1638352800+6*DAY);

    let (tup) = order_book.get_order_i_for(contract_address, 1, 1638352800, 1);
    let address = tup[2];


    // Lets check that the order was stored well using its reference
    let (test_order) = order_book.get_order_with_ref(contract_address, 1, address);
    assert test_order.price = 2;
    assert test_order.amount = 100;
    assert test_order.start_date = 1638352800;
    //should return 0
    let (test_order0) = order_book.get_order_with_ref(contract_address, 100, address);
    assert test_order0.price = 0;
    assert test_order0.amount = 0;

    //Test that the orders were stored in the order book(every of the (6 days+1) 7 days maps to a tuple(price, order_ref))
    //Day 1 (1638352800)
    let (n_orders_day1) =  order_book.get_n_orders_for(contract_address, _day = 1638352800, dir = 1);
    assert n_orders_day1 = 1;
    let (order_book_order1_day1) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800, dir = 1);
    assert order_book_order1_day1[0] = 2;
    //Day 2
    let (n_orders_day2) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + DAY, dir = 1);
    assert n_orders_day2 = 1;
    let (order_book_order1_day2) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800 + DAY, dir = 1);
    assert order_book_order1_day1[1] = 1;
    //Day 7
    let (n_orders_day7) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + 6*DAY, dir = 1);
    assert n_orders_day7 = 1;
    let (order_book_order1_day7) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800 + 6*DAY, dir = 1);
    assert order_book_order1_day7[0] = 2;

    //Day 8 should return 0 as not existing
    let (n_orders_day8) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + 7*DAY, dir = 1);
    assert n_orders_day8 = 0;
    let (order_book_order1_day8) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800 + 7*DAY, dir = 1);
    assert order_book_order1_day8[1] = 0;


    order_book.create_order(contract_address, _amount=1000, _price=35, _direction=0, _start_date=1638352800, _end_date=(1638352800 + 29*DAY));
    
    let (test_order2) = order_book.get_order_with_ref(contract_address, 2, address);
    assert test_order2.price = 35;

    //Day 1 (1638352800)
    let (n_orders_day1_again) =  order_book.get_n_orders_for(contract_address, _day = 1638352800, dir = 0); //later for felt packing, 8bytes is more than enough to represent dates.
    assert n_orders_day1_again = 1;
    let (order_book_order1_day1_again) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800, dir = 0);
    assert order_book_order1_day1_again[0] = 35;

    //Day 10
    let (n_orders_day10) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + 9*DAY, dir = 0);
    assert n_orders_day10 = 1;
    let (order_book_order1_day9) = order_book.get_order_i_for(contract_address, _i = 1, _day = 1638352800 + 9*DAY, dir = 0);
    assert order_book_order1_day9[0] = 35;

    ////Test order with price 0 and nn, it should fail.
    //order_book.create_order(contract_address, _amount=100, _price=0, _direction=1, _start_date=1638352800, _end_date=1638352800 + 2*DAY);
    //order_book.create_order(contract_address, _amount=-100, _price=3, _direction=1, _start_date=1638352800, _end_date=1638352800 + 2*DAY);
    //order_book.create_order(contract_address, _amount=100, _price=-2, _direction=1, _start_date=1638352800, _end_date=1638352800 + 2*DAY);
    return();
}

@external
func test_get_spot_for_min{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
 
    //Lets create 3 orders of for the duration of 2 days.
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=200, _price=6, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=10, _price=4, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=10, _price=45, _direction=1, _start_date=1638352800, _end_date=1638525600);

    let (min_price_index) = order_book.get_spot_for_min(contract_address, _day = 1638352800);
    assert min_price_index = 3;

    //Lets create 3 more orders of for the duration of 2 days.
    order_book.create_order(contract_address, _amount=2, _price=10, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=200, _price=2, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=1, _start_date=1638352800, _end_date=1638525600);

    let (min_price_index2) = order_book.get_spot_for_min(contract_address, _day = 1638352800);
    assert min_price_index2 = 6;

    //Lets create 3 more orders of for the duration of 2 days but with repeating prices.
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=200, _price=10, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=1, _start_date=1638352800, _end_date=1638525600);
 
    let (min_price_index3) = order_book.get_spot_for_min(contract_address, _day = 1638352800);
    assert min_price_index3 = 6;

    //Lets create 3 more orders of for the duration of 2 days but with 0 amount.
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=0, _price=2, _direction=1, _start_date=1638352800, _end_date=1638525600);
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=1, _start_date=1638352800, _end_date=1638525600);
 
    let (min_price_index4) = order_book.get_spot_for_min(contract_address, _day = 1638352800);
    assert min_price_index4 = 6;

    return();
}

@external
func test_get_spot_for_max{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;

    local contract_address: felt;
     // We deploy contract and put its address into a local variable.
    %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    
    //Lets create 8 orders of for the duration of 2 days.
    const SEPTEMBER_3 = 1693692000;
    const SEPTEMBER_4 = 1693778400;

    //Lets create 4 orders of for the duration of 2 days.
    order_book.create_order(contract_address, _amount=10, _price=1, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=200, _price=6, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=10, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=10, _price=45, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);

    let (max_price_index) = order_book.get_spot_for_max(contract_address, _day = SEPTEMBER_3);
    assert max_price_index = 4;

    //Lets create 3 more orders of for the duration of 2 days.
    order_book.create_order(contract_address, _amount=2, _price=10, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=200, _price=2, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=1000, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);

    let (max_price_index2) = order_book.get_spot_for_max(contract_address, _day = SEPTEMBER_3);
    assert max_price_index2 = 4;

    //Lets create 3 more orders of for the duration of 2 days but with repeating prices.
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=200, _price=100, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
 
    let (max_price_index3) = order_book.get_spot_for_max(contract_address, _day = SEPTEMBER_3);
    assert max_price_index3 = 9;

    //Lets create 3 more orders of for the duration of 2 days but with 0 amount.
    order_book.create_order(contract_address, _amount=0, _price=4, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=2, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
    order_book.create_order(contract_address, _amount=0, _price=1, _direction=0, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_4);
 
    let (max_price_index4) = order_book.get_spot_for_max(contract_address, _day = SEPTEMBER_3);
    assert max_price_index4 = 9;

    return();
}

// @external
// func test_fill_day{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
//     alloc_locals;

//     local contract_address: felt;
//      // We deploy contract and put its address into a local variable.
//     %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
    
//     //Lets create 3 orders of for the duration of 3 days.
//     const SEPTEMBER_3 = 1693692000;
//     const SEPTEMBER_5 = 1693864800;
//     order_book.create_order(contract_address, _amount=100, _price=7, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
//     order_book.create_order(contract_address, _amount=100, _price=6, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);
//     order_book.create_order(contract_address, _amount=30, _price=4, _direction=1, _start_date=SEPTEMBER_3, _end_date=SEPTEMBER_5);

//     let (test_fill_day) = order_book.fill_day(contract_address,_amount_left = 10, _price = 6, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day = 20; //For test purposes it returns the remaining amount available in the order book

//     let (test_fill_day2) = order_book.fill_day(contract_address,_amount_left = 10, _price = 5, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day2 = 10;

//     let (test_fill_day3) = order_book.fill_day(contract_address,_amount_left = 10, _price = 5, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day3 = 0;

//     let (test_fill_day4) = order_book.fill_day(contract_address,_amount_left = 10, _price = 5, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day4 = 6; //As there is not enough YTs available for that price, returns the best price.

//     let (test_fill_day5) = order_book.fill_day(contract_address,_amount_left = 150, _price = 10, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day5 = 50;

//     let (test_fill_day5) = order_book.fill_day(contract_address,_amount_left = 10, _price = 6, _direction = 1, _day = SEPTEMBER_3);
//     assert test_fill_day5 = 7;

//     return();
// }

//get_next_slot must be set external to be able to test it and place the function fill in this file as well as.
// @external
// func test_fill_price_array_from_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(){
//     alloc_locals;

//     local contract_address: felt;
//      // We deploy contract and put its address into a local variable.
//     %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}
//     //Lets create 5 orders of for the duration of 7 days.
//     order_book.create_order(contract_address, _amount=100, _price=1, _direction=1, _start_date=1638352800, _end_date=1638871205);
//     order_book.create_order(contract_address, _amount=200, _price=2, _direction=1, _start_date=1638352800, _end_date=1638871205);
//     order_book.create_order(contract_address, _amount=300, _price=3, _direction=1, _start_date=1638352800, _end_date=1638871205);
//     order_book.create_order(contract_address, _amount=400, _price=4, _direction=1, _start_date=1638352800, _end_date=1638871205);
//     order_book.create_order(contract_address, _amount=500, _price=5, _direction=1, _start_date=1638352800, _end_date=1638871205);

//     let (array_size_p1) = order_book.get_next_slot_on_day(contract_address, 1638352800, 1);
//     assert array_size_p1 = 6;

//     let (price_array) = alloc();
//     fill( _day = 1638352800, _i = 1, _new_array_len = array_size_p1-1, _new_array = price_array);
//     assert price_array[0] = 7;
//     assert price_array[1] = 7;
//     assert price_array[2] = 7;
//     assert price_array[3] = 7;
//     assert price_array[4] = 7;
//     assert price_array[5] = 1; //passes because the slot is not allocated

//     return();
// }

// func fill{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(_day: felt, _i: felt, _new_array_len: felt, _new_array: felt*){
//     // let (order) = order_book.read(_day, _i);
//     if (_i == _new_array_len+1){
//         return();
//     }
//     assert _new_array[_i-1] = 7; //order[0];
//     return fill(_day= _day, _i = (_i + 1), _new_array_len = _new_array_len, _new_array = _new_array);
// }


// next_slot_on_day must be set to @external in order for the test to work
// @external
// func test_get_next_slot_on_day{syscall_ptr: felt*, range_check_ptr}() {
//     alloc_locals;

//     local contract_address: felt;
//      // We deploy contract and put its address into a local variable.
//     %{ ids.contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

//     //Test of adding an overlapping order of 30 days starting the same date.
//     order_book.create_order(contract_address, _amount=2000, _price=70, _direction=1, _start_date=1638352800, _end_date=(1638352800 + 29*DAY));
//     order_book.create_order(contract_address, _amount=4000, _price=140, _direction=1, _start_date=1638352800, _end_date=(1638352800 + 6*DAY));
    
//     //Day 1
//     let (test_n_orders) =  order_book.get_n_orders_for(contract_address, _day = 1638352800);
//     assert test_n_orders = 2;
//     // Should be the same
//     let (test_idx1_day1) = order_book.get_next_slot_on_day(contract_address, _day = 1638352800, _i = 1);
//     assert test_idx1_day1 = 2 +1; // 2 the number of elements + the next free slot;

//     order_book.create_order(contract_address, _amount=8000, _price=240, _direction=1, _start_date=1638352800, _end_date=(1638352800 + 6*DAY));
//     // Day 4
//     let (test_n_orders2) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + 3*DAY);
//     assert test_n_orders2 = 3;

//     let (test_idx1_day4) = order_book.get_next_slot_on_day(contract_address, _day = 1638352800 + 3*DAY, _i = 1);
//     assert test_idx1_day4 = 3 +1; 

//     //Day 40 (should return 1)
//     let (test_n_orders3) =  order_book.get_n_orders_for(contract_address, _day = 1638352800 + 39*DAY);
//     assert test_n_orders3 = 0;

//     let (test_idx1_day40) = order_book.get_next_slot_on_day(contract_address, _day = 1638352800 + 39*DAY, _i = 1);
//     assert test_idx1_day40 = 0 +1;

//     return();
// }

