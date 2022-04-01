pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/* This contract represents a factory to create an arbitrary number of orderbooks
 * for unique trading pairs. If an orderbook for the trading pair already exists
 * then contract execution will revert.
 */
contract OrderbookFactory {
    // number of pairs supported
    uint256 public pairsSupported;

    // mapping of existing orderbooks
    mapping(bytes32 => address) public orderbooks;

    // event emitted every time a new token pair is added
    event NewPair(address indexed token1, address indexed token2);

    // Creates a new orderbook contract instance for the token pair
    function addPair(address _token1, address _token2) external {
        require(_token1 != _token2, "Tokens must be different");

        address token1;
        address token2;

        /* This ensures that token addresses are order correctly, this way if
         * the same pair is entered but in different order, a new orderbook will
         * NOT be created!
         */
        if (uint160(_token1) > uint160(_token2)) {
            token1 = _token1;
            token2 = _token2;
        } else {
            token1 = _token2;
            token2 = _token1;
        }

        // mapping identifier is computed from the hash of the ordered addresses
        bytes32 identifier = keccak256(abi.encodePacked(token1, token2));
        require(
            orderbooks[identifier] == address(0),
            "Token pair already exists"
        );

        /* create the new orderbook contract for the pair and store its address
         * in the orderbooks mapping
         */
        orderbooks[identifier] = address(new Orderbook(token1, token2));
        pairsSupported++;

        emit NewPair(token1, token2);
    }
}

/* This contract represents an orderbook with a buy side and sell side of the
 * book. This contract maintains an ordered list of both the buy side and the
 * sell side of the book and allows any user to remove his or her order. There
 * is also functionality to return both the buy and sell side of the book. Please
 * see the READ.me for further assumptions.
 */
contract Orderbook {
    IERC20 token1;
    IERC20 token2;

    // Order struct containing price, quantity, and date created
    struct Order {
        uint256 price;
        uint256 quantity;
        uint256 date;
    }

    // mapping of buyer address to buy order
    mapping(address => Order) buyOrders;

    // mapping used to preserve order based on buy price
    mapping(address => address) nextBuy;

    // overall buy order count
    uint256 public buyCount;

    // mapping of seller address to sell order
    mapping(address => Order) sellOrders;

    // mapping used to preserve order based on sell price
    mapping(address => address) nextSell;

    // overall sell order count
    uint256 public sellCount;

    // BUFFER used to signal beginning and end of order mappings
    address constant BUFFER = address(1);

    // event emitted whenever a buy order is placed
    event BuyOrderPlaced(
        uint256 indexed price,
        uint256 quantity,
        address indexed buyer
    );

    // event emitted whenever a buy order is cancelled
    event CancelBuyOrder(address indexed buyer);

    // event emitted whenever a sell order is placed
    event SellOrderPlaced(
        uint256 indexed price,
        uint256 quantity,
        address indexed seller
    );

    // event emitted whenever a sell order is cancelled
    event CancelSellOrder(address indexed seller);

    // initialize token1 and token2 of the pair
    constructor(address _token1, address _token2) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);

        // initialize order mappings
        nextBuy[BUFFER] = BUFFER;
        nextSell[BUFFER] = BUFFER;
    }

    /* Helper function used to verify the correct insertion position of a
     * buy order when it is added to the buy side. Returns true if the order is
     * at least as expensive as the previous buy order in the list and definitely
     * more expensive than the next order in the list (for descending order)
     */
    function _verifyIndexBuy(
        address prev,
        uint256 price,
        address next
    ) internal view returns (bool) {
        return ((prev == BUFFER || price <= buyOrders[prev].price) &&
            (next == BUFFER || price > buyOrders[next].price));
    }

    /* Helper function used to verify the correct insertion position of a
     * sell order when it is added to the sell side. Returns true if the order is
     * at least as cheap as the previous sell order in the list and definitely
     * less expensive than the next order in the list (for ascending order)
     */
    function _verifyIndexSell(
        address prev,
        uint256 price,
        address next
    ) internal view returns (bool) {
        return ((prev == BUFFER || price >= sellOrders[prev].price) &&
            (next == BUFFER || price < sellOrders[next].price));
    }

    /* Helper function that finds the previous buy order address for the new buy
     * order to add to the list based on the new buy order price.
     */
    function _findPrevBuy(uint256 price) internal view returns (address) {
        address prev = BUFFER;
        while (true) {
            if (_verifyIndexBuy(prev, price, nextBuy[prev])) {
                return prev;
            }
            prev = nextBuy[prev];
        }
    }

    /* Helper function that finds the previous sell order address for the new
     * sell order to add to the list based on the new sell order price.
     */
    function _findPrevSell(uint256 price) internal view returns (address) {
        address prev = BUFFER;
        while (true) {
            if (_verifyIndexSell(prev, price, nextSell[prev])) {
                return prev;
            }
            prev = nextSell[prev];
        }
    }

    /* Finds the previous address of the target address in the order mapping of
     * either buy or sell order addresses. Used for removing buy or sell orders.
     */
    function _getPrevious(address target) internal view returns (address) {
        address current = BUFFER;
        while (nextBuy[current] != BUFFER) {
            if (nextBuy[current] == target) {
                return current;
            }
            current = nextBuy[current];
        }
    }

    // Places a buy order and locks associated collateral
    function placeBuy(uint256 _price, uint256 _quantity) external {
        // Only one buy order per address
        require(
            buyOrders[msg.sender].date == 0,
            "First delete existing buy order"
        );
        require(
            _price != 0 && _quantity != 0,
            "Must have nonzero pice and quantity"
        );

        // Create a new order in the buy order mapping for msg.sender
        buyOrders[msg.sender] = Order(_price, _quantity, block.timestamp);

        /* Add msg.sender into the appropriate position in the ordering mapping.
         * This is similar to linked list insertion
         */
        address prev = _findPrevBuy(_price);
        address temp = nextBuy[prev];
        nextBuy[prev] = msg.sender;
        nextBuy[msg.sender] = temp;

        // Increment the overall buy count
        buyCount++;

        /* Transfer the buy order quantity of token1 from the buyer to the
         * orderbook contract. This locks the associated collateral
         */
        token1.transferFrom(msg.sender, address(this), _quantity);

        // Emit buy order placed event
        emit BuyOrderPlaced(_price, _quantity, msg.sender);
    }

    // Cancels the buy order associated with msg.sender if it exists
    function cancelBuy() external {
        require(
            buyOrders[msg.sender].date != 0,
            "Buy order must already exist"
        );

        // Store quantity of buy order to refund msg.sender with correct amount
        uint256 quantity = buyOrders[msg.sender].quantity;

        // Find the previous address of the msg.sender in the ordering mapping
        address prev = _getPrevious(msg.sender);

        // Delete msg.sender from ordering mapping. Similar to linked list deletion
        nextBuy[prev] = nextBuy[msg.sender];

        // Delete buy order from buy order mapping and ordering mapping
        delete nextBuy[msg.sender];
        delete buyOrders[msg.sender];

        // Decrement the buy count
        buyCount--;

        // Unlock associated collateral and send it back to msg.sender
        token1.transferFrom(address(this), msg.sender, quantity);

        // Emit a cancel buy order event
        emit CancelBuyOrder(msg.sender);
    }

    // Places a sell order and locks associated collateral
    function placeSell(uint256 _price, uint256 _quantity) external {
        // Only one sell order per address
        require(
            sellOrders[msg.sender].date == 0,
            "First delete existing sell order"
        );
        require(
            _price != 0 && _quantity != 0,
            "Must have nonzero pice and quantity"
        );

        // Create a new order in the sell order mapping for msg.sender
        sellOrders[msg.sender] = Order(_price, _quantity, block.timestamp);

        /* Add msg.sender into the appropriate position in the ordering mapping.
         * This is similar to linked list insertion
         */
        address prev = _findPrevSell(_price);
        address temp = nextSell[prev];
        nextSell[prev] = msg.sender;
        nextSell[msg.sender] = temp;

        // Increment the sell count
        sellCount++;

        /* Transfer the sell order quantity of token2 from the seller to the
         * orderbook contract. This locks the associated collateral
         */
        token2.transferFrom(msg.sender, address(this), _quantity);

        // Emit a sell order placed event
        emit SellOrderPlaced(_price, _quantity, msg.sender);
    }

    // Cancels the sell order associated with msg.sender if it exists
    function cancelSell() external {
        require(
            sellOrders[msg.sender].date != 0,
            "Sell order must already exist"
        );

        // Store quantity of sell order to refund msg.sender with correct amount
        uint256 quantity = sellOrders[msg.sender].quantity;

        // Find the previous address of the msg.sender in the ordering mapping
        address prev = _getPrevious(msg.sender);

        // Delete msg.sender from ordering mapping. Similar to linked list deletion
        nextSell[prev] = nextSell[msg.sender];

        // Delete sell order from sell order mapping and ordering mapping
        delete nextSell[msg.sender];
        delete sellOrders[msg.sender];

        // Decrement sell count
        sellCount--;

        // Unlock associated collateral and send it back to msg.sender
        token2.transferFrom(address(this), msg.sender, quantity);

        // Emit a cencel sell order event
        emit CancelSellOrder(msg.sender);
    }

    /* Returns the buy side of the orderbook in three separate arrays. The first
     * array contains all the addresses with active buy orders, and the second
     * and third arrays contain the associated prices and quantities of these
     * buy orders respectively. Arrays are returned in descending order
     */
    function getBuySide()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // Instantiate three arrays equal in length to the total buy count
        address[] memory addressTemp = new address[](buyCount);
        uint256[] memory priceTemp = new uint256[](buyCount);
        uint256[] memory quantityTemp = new uint256[](buyCount);

        // Set current address equal to the first buy order address
        address current = nextBuy[BUFFER];

        // Iterate through each array and store the corresponding values
        for (uint256 i = 0; i < addressTemp.length; i++) {
            addressTemp[i] = current;
            Order storage order = buyOrders[current];

            priceTemp[i] = order.price;
            quantityTemp[i] = order.quantity;

            current = nextBuy[current];
        }

        // Return the three arrays
        return (addressTemp, priceTemp, quantityTemp);
    }

    /* Returns the sell side of the orderbook in three separate arrays. The first
     * array contains all the addresses with active sell orders, and the second
     * and third arrays contain the associated prices and quantities of these
     * sell orders respectively. Arrays are returned in ascending order
     */
    function getSellSide()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        // Instantiate three arrays equal in length to the total sell count
        address[] memory addressTemp = new address[](sellCount);
        uint256[] memory priceTemp = new uint256[](sellCount);
        uint256[] memory quantityTemp = new uint256[](sellCount);

        // Set current address equal to the first sell order address
        address current = nextSell[BUFFER];

        // Iterate through each array and store the corresponding values
        for (uint256 i = 0; i < addressTemp.length; i++) {
            addressTemp[i] = current;
            Order storage order = sellOrders[current];

            priceTemp[i] = order.price;
            quantityTemp[i] = order.quantity;

            current = nextSell[current];
        }

        // Return the three arrays
        return (addressTemp, priceTemp, quantityTemp);
    }

    /* Returns the spread of the orderbook defined as the absolute value of the
     * difference between the highest buy price and the lowest sell price.
     */
    function getSpread() external view returns (uint256) {
        uint256 bestSell = sellOrders[nextSell[BUFFER]].price;
        uint256 bestBuy = buyOrders[nextBuy[BUFFER]].price;

        // Return the spread as a positive number (uint must be positive)
        return bestBuy > bestSell ? bestBuy - bestSell : bestSell - bestBuy;
    }
}
