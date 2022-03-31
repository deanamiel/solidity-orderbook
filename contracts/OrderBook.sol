pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract OrderBookFactory {
    uint256 public pairsSupported;
    mapping(bytes32 => address) public orderbooks;

    event NewPair(address indexed token1, address indexed token2);

    function addPair(address _token1, address _token2) external {
        require(_token1 != _token2, "Tokens must be different");

        address token1;
        address token2;

        if (uint160(_token1) > uint160(_token2)) {
            token1 = _token1;
            token2 = _token2;
        } else {
            token1 = _token2;
            token2 = _token1;
        }

        bytes32 identifier = keccak256(abi.encodePacked(token1, token2));
        require(
            orderbooks[identifier] == address(0),
            "Token pair already exists"
        );

        orderbooks[identifier] = address(new OrderBook(token1, token2));
        pairsSupported++;

        emit NewPair(token1, token2);
    }
}

contract OrderBook {
    IERC20 token1;
    IERC20 token2;

    struct Order {
        uint256 price;
        uint256 quantity;
        uint256 date;
    }

    mapping(address => Order) buyOrders;
    mapping(address => address) nextBuy;
    uint256 public buyCount;

    mapping(address => Order) sellOrders;
    mapping(address => address) nextSell;
    uint256 public sellCount;

    address constant BUFFER = address(1);

    event BuyOrderPlaced(
        uint256 indexed price,
        uint256 quantity,
        address indexed buyer
    );

    event CancelBuyOrder(address indexed buyer);

    event SellOrderPlaced(
        uint256 indexed price,
        uint256 quantity,
        address indexed seller
    );

    event CancelSellOrder(address indexed seller);

    constructor(address _token1, address _token2) {
        token1 = IERC20(_token1);
        token2 = IERC20(_token2);

        nextBuy[BUFFER] = BUFFER;
        nextSell[BUFFER] = BUFFER;
    }

    function _verifyIndexBuy(
        address prev,
        uint256 price,
        address next
    ) internal view returns (bool) {
        return ((prev == BUFFER || price <= buyOrders[prev].price) &&
            (next == BUFFER || price > buyOrders[next].price));
    }

    function _verifyIndexSell(
        address prev,
        uint256 price,
        address next
    ) internal view returns (bool) {
        return ((prev == BUFFER || price >= buyOrders[prev].price) &&
            (next == BUFFER || price < buyOrders[next].price));
    }

    function _findPrevBuy(uint256 price) internal view returns (address) {
        address prev = BUFFER;
        while (true) {
            if (_verifyIndexBuy(prev, price, nextBuy[prev])) {
                return prev;
            }
            prev = nextBuy[prev];
        }
    }

    function _findPrevSell(uint256 price) internal view returns (address) {
        address prev = BUFFER;
        while (true) {
            if (_verifyIndexSell(prev, price, nextBuy[prev])) {
                return prev;
            }
            prev = nextBuy[prev];
        }
    }

    function _getPrevious(address target) internal view returns (address) {
        address current = BUFFER;
        while (nextBuy[current] != BUFFER) {
            if (nextBuy[current] == target) {
                return current;
            }
            current = nextBuy[current];
        }
    }

    function placeBuy(uint256 _price, uint256 _quantity) external {
        require(
            buyOrders[msg.sender].date == 0,
            "First delete existing buy order"
        );

        buyOrders[msg.sender] = Order(_price, _quantity, block.timestamp);
        address prev = _findPrevBuy(_price);
        address temp = nextBuy[prev];
        nextBuy[prev] = msg.sender;
        nextBuy[msg.sender] = temp;
        buyCount++;

        token1.transferFrom(msg.sender, address(this), _quantity);

        emit BuyOrderPlaced(_price, _quantity, msg.sender);
    }

    function cancelBuy() external {
        require(
            buyOrders[msg.sender].date != 0,
            "Buy order must already exist"
        );

        uint256 quantity = buyOrders[msg.sender].quantity;
        address prev = _getPrevious(msg.sender);
        nextBuy[prev] = nextBuy[msg.sender];
        delete nextBuy[msg.sender];
        delete buyOrders[msg.sender];
        buyCount--;

        token1.transferFrom(address(this), msg.sender, quantity);

        emit CancelBuyOrder(msg.sender);
    }

    function placeSell(uint256 _price, uint256 _quantity) external {
        require(
            sellOrders[msg.sender].date == 0,
            "First delete existing sell order"
        );

        sellOrders[msg.sender] = Order(_price, _quantity, block.timestamp);
        address prev = _findPrevSell(_price);
        address temp = nextSell[prev];
        nextSell[prev] = msg.sender;
        nextSell[msg.sender] = temp;
        sellCount++;

        token2.transferFrom(msg.sender, address(this), _quantity);

        emit SellOrderPlaced(_price, _quantity, msg.sender);
    }

    function cancelSell() external {
        require(
            sellOrders[msg.sender].date != 0,
            "Sell order must already exist"
        );

        uint256 quantity = sellOrders[msg.sender].quantity;
        address prev = _getPrevious(msg.sender);
        nextSell[prev] = nextSell[msg.sender];
        delete nextSell[msg.sender];
        delete sellOrders[msg.sender];
        sellCount--;

        token2.transferFrom(address(this), msg.sender, quantity);

        emit CancelSellOrder(msg.sender);
    }

    function getBuySide()
        external
        view
        returns (
            address[] memory,
            uint256[] memory,
            uint256[] memory
        )
    {
        address[] memory addressTemp = new address[](buyCount);
        uint256[] memory priceTemp = new uint256[](buyCount);
        uint256[] memory quantityTemp = new uint256[](buyCount);

        address current = nextBuy[BUFFER];
        for (uint256 i = 0; i < addressTemp.length; i++) {
            addressTemp[i] = current;
            Order storage order = buyOrders[current];

            priceTemp[i] = order.price;
            quantityTemp[i] = order.quantity;

            current = nextBuy[current];
        }

        return (addressTemp, priceTemp, quantityTemp);
    }
}
