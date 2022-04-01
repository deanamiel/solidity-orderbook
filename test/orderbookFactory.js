const OrderbookFactory = artifacts.require("OrderbookFactory");
const Token1 = artifacts.require("Token1");
const Token2 = artifacts.require("Token2");
const web3 = require("web3");

contract("OrderbookFactory", () => {
    it('should add new pair', async () => {
        // const storage = await Simple.new();
        // await storage.setData(10);
        // const data = await storage.getData();
        // assert(data.toString() === '10');

        const factory = await OrderbookFactory.new();
        const token1 = await Token1.new();
        const token2 = await Token2.new();

        await factory.addPair(token1.address, token2.address);
        try {
            await factory.addPair(token1.address, token2.address);
            assert(false);
        } catch (error) {
            assert(true);
        }
        try {
            await factory.addPair(token2.address, token1.address);
            assert(false);
        } catch (error) {
            assert(true);
        }

        const tokens = [token1.address, token2.address];
        const hash1 = web3.utils.soliditySha3(tokens[0], tokens[1]);
        const hash2 = web3.utils.soliditySha3(tokens[1], tokens[0]);

        assert((await factory.orderbooks(hash1)) != "0x0000000000000000000000000000000000000000" || (await factory.orderbooks(hash2)) != "0x0000000000000000000000000000000000000000");
    })
})