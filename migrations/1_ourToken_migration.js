const OurERC20 = artifacts.require("OurERC20");

module.exports = async function (deployer, networks, accounts) {
    
    deployer.deploy(OurERC20, 1000000, {from: accounts[1]});
};