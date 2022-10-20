const SimpleExchange = artifacts.require("SimpleExchange");
const ExchangeLPToken = artifacts.require("ExchangeLPToken");

module.exports = async function (deployer,networks, accounts) {
    const lpTokenInstance = await ExchangeLPToken.deployed();
    await deployer.deploy(SimpleExchange, lpTokenInstance.address);

    const exchangeInstance = await SimpleExchange.deployed();

    await lpTokenInstance.passMinterBurnerRole(exchangeInstance.address);

};