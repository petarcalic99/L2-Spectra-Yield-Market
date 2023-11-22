# L2-Yield-Marketplace 
(Forked the project form our APWine git for the ECMP program purpose in order not to make the project public yet as it is not finished)

## Context
The choice of making APWine v1 rely on AMM limited technologicaly the use and better adoption of the protocol. It was decided to switch to an Order book approach as the emergence of a new technology: Starknet, a validity rollup, makes realizable the implementation of what would be such a costly structure on the Ethereum network.

## Structure of the contracts
Two main components: The order book that has a Matching Engine, and the bridge.
The Order book contract maintains the structure of the order book, and provides functionalities to create and fill orders. It contains internal functions that act as a matching engine extracting the best priced order for a user when the wanted parameters are compatible so that everything happens automaticaly.
The bridge contract keeps the real funds locked on the L1 side which is the real contract thats accumulating yield. The Starknet side of the bridge allocates the funds to the corresponding owner and allows him to use them in the order book when selling or buying future yield. 
Tests have been written using protostar and simulate the real usage of the contracts.

## The Order book
An order book is a list-like structure that stores buying and selling (bid/ask) orders for a specific asset (in our case the unrealized yield of a certain period in the future), and organize itself by the buying/selling price. They contain additional information such as the trading size or amount, and the identity of the person issuing the order. There are no requirements to deposit orders, hence anyone can deposit an order and wait for someone else to fill it. An order can also be partially filled, meaning that someone will buy parts of existing orders only if parts of an order’s amounts, prices and dates
match.
It has been chosen to program the order book as a storage variable mapping a date to a list of orders. That list represents the orders available for the corresponding day. This structure is very useful as the action of filling an order needs to happen automatically. Users decide to post a buying or selling order, and the matching engine iterates on the available days to check if there are orders compatible with users demands. If so the matching engine fills the orders and if not posts the unmatched order in the order book.


