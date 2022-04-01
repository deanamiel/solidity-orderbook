const OrderbookFactory = artifacts.require("OrderbookFactory");
const Token1 = artifacts.require("Token1");
const Token2 = artifacts.require("Token2");

module.exports = async function (deployer, network, addresses) {
  await deployer.deploy(OrderbookFactory);
  await deployer.deploy(Token1);
  await deployer.deploy(Token2);
};
