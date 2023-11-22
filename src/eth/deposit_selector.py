from starkware.starknet.compiler.compile import \
    get_selector_from_name

#Run this script in a cairo virtual environment 
print(get_selector_from_name('handle_deposit_YT'))
