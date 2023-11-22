import sys
import numpy as np
import subprocess
import time
import json

## polling list of hashes over given time interval until all accepted on StarkNet
## cached accepted tx_hash to avoid unnecessary polling of accepted tx
def _poll_list_tx_hashes_until_all_accepted(list_of_tx_hashes, interval_in_sec):
	accepted_list = [False for _ in list_of_tx_hashes]

	while True:
		all_accepted = True
		print(f'> begin polling tx status.')
		for i, tx_hash in enumerate(list_of_tx_hashes):
			if accepted_list[i]:
				continue
			cmd = f"starknet tx_status --hash={tx_hash}".split(' ')
			ret = subprocess_run(cmd)
			ret = json.loads(ret)
			if ret['tx_status'] != 'ACCEPTED_ON_L2':
				print(f"> {tx_hash} ({ret['tx_status']}) not accepted onchain yet.")
				all_accepted = False
				break
			else:
				print(f"> {i}th hash {tx_hash} is accepted onchain.")
				accepted_list[i] = True
		if all_accepted:
			break
		else:
			print(f'> retry polling in {interval_in_sec} seconds.')
			time.sleep(interval_in_sec)
	print(f'> all tx hashes are accepted onchain.')
	return
	
	
def subprocess_run (cmd):
	result = subprocess.run(cmd, stdout=subprocess.PIPE)
	result = result.stdout.decode('utf-8')[:-1] # remove trailing newline
	return result
	
	
## invoking create order
## returns the tx hash
def create_and_fill_order(contract_addr, amount, price, direction, start_date, end_date):
	cmd = f"starknet invoke --address {contract_addr} --abi order_book_abi.json --function create_and_fill --inputs {amount} {price} {direction} {start_date} {end_date}"
	cmd = cmd.split(' ')
	ret = subprocess_run(cmd)
	ret = ret.split(': ')
	#addr = ret[1].split('\n')[0]
	tx_hash = ret[-1]
	return tx_hash

##########################
##########################

DATES = []
ORDER_BOOK_ADD = "0x07d8292ec203cee3aab860b9a8c64632012641a217918137a55c33d73cad03f1"
SAMPLE_AMOUNT = 1000
SAMPLE_PRICE = 5
SAMPLE_DIRECTION = 0
SAMPLE_DURATION = 6

#Lets fill the starting dates list
#1696118400 corresponds to October 1, 2023 0:00:00 
for i in range (60):
	DATES += [1696118400 + 86400*i]

# invoke the contracts and save the tx hashes
tx_hashes = {}
for start_date in DATES:
	tx_hashes[start_date] = create_and_fill_order(ORDER_BOOK_ADD, SAMPLE_AMOUNT, SAMPLE_PRICE, SAMPLE_DIRECTION, start_date, start_date + SAMPLE_DURATION*86400)
	#LOCK THE FUNCTION UNTIL THE INVOKE IS ACCEPTED ON CHAIN OR THE REST OF THE INVOKES WILL GET NOUNCE REVOKED
	#TODO: Check the status of the tx hash and Loop (with sleep of 3s) until it passes and continue 
	cmd = f"starknet tx_status --hash={tx_hashes[start_date]}".split(' ')
	ret = subprocess_run(cmd)
	ret = json.loads(ret)
	while ret['tx_status'] != 'ACCEPTED_ON_L2':
		cmd = f"starknet tx_status --hash={tx_hashes[start_date]}".split(' ')
		ret = subprocess_run(cmd)
		ret = json.loads(ret)
		print(f"> {tx_hashes[start_date]} ({ret['tx_status']})")
		time.sleep(3) #try every 3s for ex
	
	print(f"> invoke on day: {start_date} with tx hash: {tx_hashes[start_date]} is accepted onchain.")
	print()

## export file listing all contract's addresses
with open('created_order_hashes.txt', 'a') as f:
	f.write('Invoke tx hashes:\n')
	for start_date in DATES:
		f.write(f"order of 7 days starting at {start_date} invoked with tx_hash={tx_hashes[start_date]}")
		f.write('\n')
	f.write('\n')
print('> Created created_order_hashes.txt')

'''
## Monitor tx hashes to wait for all invokes to be accepted on chain
print(f'> Begin monitoring tx hashes for contract deployment')
invoked_tx_hashes = [tx_hashes[start_date] for start_date in DATES]
_poll_list_tx_hashes_until_all_accepted(invoked_tx_hashes, interval_in_sec=10)
'''