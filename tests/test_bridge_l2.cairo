%lang starknet
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc

@contract_interface
namespace bridge_l2 {
    
    func get_governor() -> (address: felt) {
    }

    func initialize(init_array_len: felt, init_array: felt*) {
    }

    func set_l1_bridge(address: felt) {
    }

    func get_l1_bridge() -> (address: felt) {
    }

    func test_get_caller() -> (res: felt) {
    }

    func get_user_balance_YT(_user_address: felt) -> (balance: felt) {
    }

    func get_user_claimable_yield(_user_address: felt) -> (balance: felt) {
    }

    func get_user_balance_underlying(_user_address: felt) -> (balance: felt) {
    }

    func initiate_withdraw_YT(l1_recipient: felt, user: felt, amount: felt) {
    }

    func set_order_book_contract(address: felt) {
    }

}

//hook to avoid deploying the contract in each test
@external
func __setup__() {
    %{ context.contract_a_address = deploy_contract("./src/bridge_l2.cairo").contract_address %}
    %{ context.order_book_contract_address = deploy_contract("./src/order_book.cairo").contract_address %}

    return ();
}

@external
func test_initialization{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    local contract_address;
    %{ ids.contract_address = context.contract_a_address %}

    let (this_address) = bridge_l2.test_get_caller(contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(contract_address ,input_len, input);

    //test the address of the governor was well initalized
    let (bridge_gov) = bridge_l2.get_governor(contract_address);
    assert bridge_gov = this_address; 

    //Lets set the address of the l1 bridge
    //(This caller was set as the governor so it works, otherwise it fails)
    bridge_l2.set_l1_bridge(contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(contract_address);
    assert l1_address = 0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7;

    // //test the function was reverted because the bridge is already set (This will stop the execution)
    // %{ expect_revert(error_message="The bridge was already set") %}
    // bridge_l2.set_l1_bridge(contract_address ,0xAbc3b0028e3AFA0cb865C28E6C57f0a3A77c5cd5);

    //Lets simulate a deposit
    %{ send_message_to_l2(fn_name="handle_deposit_underlying",from_address=ids.l1_address ,to_address=ids.contract_address , payload=[123456789, 50]) %}
    let (test_deposit1) = bridge_l2.get_user_balance_underlying(contract_address ,123456789);
    assert test_deposit1 = 50;

    %{ send_message_to_l2(fn_name="handle_deposit_underlying",from_address=ids.l1_address ,to_address=ids.contract_address , payload=[123456789, 50]) %}
    let (test_deposit2) = bridge_l2.get_user_balance_underlying(contract_address ,123456789);
    assert test_deposit2 = 100;

    //Test  that depositing an amount of 0 reverts(The execution of the test stops after the revert.)
    %{ expect_revert(error_message="INVALID_AMOUNT") %}
    %{ send_message_to_l2(fn_name="handle_deposit_underlying",from_address=ids.l1_address ,to_address=ids.contract_address , payload=[123456789, 0]) %}

    return ();
}

@external
func test_deposit_withdraw_YT{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    alloc_locals;
    
    local contract_address;
    %{ ids.contract_address = context.contract_a_address %}

    local order_book_contract_address;
    %{ ids.order_book_contract_address = context.order_book_contract_address %}

    let (this_address) = bridge_l2.test_get_caller(contract_address);

    let input_len = 1;
    tempvar input: felt* = new (this_address);

    bridge_l2.initialize(contract_address ,input_len, input);
    bridge_l2.set_l1_bridge(contract_address ,0xBb03b0028e3AFA0cb865C28E6C57f0a3A77c5cd7);
    let (l1_address) = bridge_l2.get_l1_bridge(contract_address);
    bridge_l2.set_order_book_contract(contract_address, order_book_contract_address);
    
    //Lets simulate a deposit
    //(Rate is *1000)
    %{ send_message_to_l2(fn_name="handle_deposit_YT",from_address=ids.l1_address ,to_address=ids.contract_address , payload=[123456789, 100, 86400, 2000, 1000]) %}
    let (test_deposit1) = bridge_l2.get_user_balance_YT(contract_address ,123456789);
    assert test_deposit1 = 100;
    let (test_deposit2) = bridge_l2.get_user_claimable_yield(contract_address ,123456789);
    assert test_deposit2 = 0;

    %{ send_message_to_l2(fn_name="handle_deposit_YT",from_address=ids.l1_address ,to_address=ids.contract_address , payload=[123456789, 50, 86400*2, 4000, 2000]) %}
    let (test_deposit3) = bridge_l2.get_user_balance_YT(contract_address, 123456789);
    assert test_deposit3 = 150;
    let (test_deposit4) = bridge_l2.get_user_claimable_yield(contract_address, 123456789);
    assert test_deposit4 = 25;

    //Test withdrawal of YT
    bridge_l2.initiate_withdraw_YT(contract_address, 2222222, 123456789, 60);
    let (test_withdrawal1) = bridge_l2.get_user_balance_YT(contract_address, 123456789);
    assert test_withdrawal1 = 90;
    
    return();

}