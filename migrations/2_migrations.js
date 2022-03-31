const OrderbookFactory = artifacts.require("OrderbookFactory");

module.exports = function (deployer, network, addresses) {
  await deployer.deploy(OrderbookFactory);
  const factory = OrderbookFactory.deployed();

  await deployer.deploy(Token1);
  await deployer.deploy(Token2);

  const token1 = Token1.deployed();
  const token2 = Token2.deployed();
};
