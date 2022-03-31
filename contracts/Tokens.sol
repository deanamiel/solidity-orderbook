pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Token1 is ERC20 {
    address public admin;

    constructor() ERC20('TOKEN1","TK1") {
        admin = msg.sender;
        _mint(msg.sender, 1000);
    }

    function mint(address _to, uint _amount) external {
        require(msg.sender == admin,"Only admin can mint");
        _mint(_to, _amount);
    }
}

contract Token2 is ERC20 {
    address public admin;

    constructor() ERC20('TOKEN2","TK2") {
        admin = msg.sender;
        _mint(msg.sender, 1000);
    }

    function mint(address _to, uint _amount) external {
        require(msg.sender == admin,"Only admin can mint");
        _mint(_to, _amount);
    }
}