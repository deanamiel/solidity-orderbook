Solidity Orderbook

This Solidity Orderbook meets the following requirements:
1. Has a buy and sell side of the order book.
2. Anyone can retrieve a side of the orderbook. Buy orders will be returned in descending order and sell orders will be returned in ascending order.
3. Anyone can post an order to either side of the book.
4. The contract locks collateral for both buy and sell orders.
5. Anyone may cancel their buy or sell orders

Approach

There are two main contracts that implement the Solidity orderbook: the OrderbookFactory contract and the Orderbook contract. The OrderbookFactory contract can be used to create an arbitrary amount of Orderbooks each representing a unique ERC20 token pair. The contract checks to make sure that the ERC20 trading pair does not already exist before creating a new Orderbook contract instance. Additionally, the OrderbookFactory contract contains a mapping that stores all the Orderbook contract addresses that have been created based on the hash of their token pair addresses.

The Orderbook contract implements the order book functionality for each unique token pair. The contract utilizes two mappings to maintain a sorted list of orders (two mappings for the buy side and two mappings for the sell side). In this design, one mapping maps the address that submitted the order to the order struct itself. Another mapping maps each address to the address that comes next in the sequence, similar to a linked list. This design was chosen over maintaining an ordered array due to the high gas costs that would be associated with inserting and removing an element from an array (all elements in the array would need to be shifted). The Orderbook contract itself contains seven externally accessible functions that represent create, delete, and retrieve functionality for both the buy and sell side of the book and finally a getter function that returns the spread of the orderbook.

Assumptions:
1. All trading pairs will represent valid ERC20 token addresses
2. A single address can only maintain a single buy order at a time, to submit a new buy order they must first delete the existing one
3. A single address can only maintain a single sell order at a time, to submit a new sell order they must first delete the existing one
4. Token order is determined by sorting the addresses based on their uint160 casted values
5. Creating a buy order causes a token transfer of token1 to the Orderbook contract
6. Creating a sell order causes a token transfer of token2 to the Orderbook contract
7. Users must use the ERC20 approve function to approve the Orderbook contract to transfer associated token quantities for buy and sell orders respectively from the user wallet to the Orderbook contract
