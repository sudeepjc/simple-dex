const ExchangeLPToken = artifacts.require("ExchangeLPToken");

module.exports = async function (deployer,networks, accounts) {
    deployer.deploy(ExchangeLPToken);
};