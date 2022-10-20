const SimpleExchange = artifacts.require("SimpleExchange");
const ExchangeLPToken = artifacts.require("ExchangeLPToken");
const OurERC20 = artifacts.require("OurERC20");
const { BN, constants,expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

contract("Testing SimpleExchange contract ", (accounts) => {

    let supply = 1000000;
        let lpTokenDeployer =  accounts[0];
        let exchangeDeployer =  accounts[0];
        let ourTokenCreator =  accounts[1];
        let tokenBuyer =  accounts[2];

        it("Check for add & remove liqudity", async () => {
            //init
            let ourTokenInstance = await OurERC20.new(supply,{from: ourTokenCreator});
            let lpTokenInstance = await ExchangeLPToken.new();
            let simpleExchange =  await SimpleExchange.new(lpTokenInstance.address);
            
            //pre-condition
            await ourTokenInstance.approve(simpleExchange.address, web3.utils.toWei("10","ether"),{from: ourTokenCreator} );
            await lpTokenInstance.passMinterBurnerRole(simpleExchange.address);
            
            // add liquidity
            let response = await simpleExchange.addLiquidity(ourTokenInstance.address, web3.utils.toWei("10","ether"), {from: ourTokenCreator, value: web3.utils.toWei("10","ether")});
            expectEvent.inLogs(response.logs, 'AddedLiquidity', {
                user: ourTokenCreator,
                token: ourTokenInstance.address,
                tokenamount: web3.utils.toWei("10","ether"),
                ethamount: web3.utils.toWei("10","ether"),
            });

            // check contract balance
            assert.equal(await web3.eth.getBalance(simpleExchange.address), web3.utils.toWei("10","ether"), "Expected ether balance in contract");

            //check for lptoken balance
            assert.equal(await lpTokenInstance.balanceOf(ourTokenCreator), web3.utils.toWei("10","ether"), "Expected ether balance in contract");

            //remove liquidity
            response = await simpleExchange.removeLiquidity(ourTokenInstance.address, web3.utils.toWei("5","ether"), {from: ourTokenCreator});
            expectEvent.inLogs(response.logs, 'RemovedLiquidity', {
                user: ourTokenCreator,
                token: ourTokenInstance.address,
                tokenamount: web3.utils.toWei("5","ether"),
                ethamount: web3.utils.toWei("5","ether"),
            });

            // check contract balance
            assert.equal(await web3.eth.getBalance(simpleExchange.address), web3.utils.toWei("5","ether"), "Expected ether balance in contract");

            //check for lptoken balance
            assert.equal(await lpTokenInstance.balanceOf(ourTokenCreator), web3.utils.toWei("5","ether"), "Expected ether balance in contract");

            //remove all liquidity
            response = await simpleExchange.removeLiquidity(ourTokenInstance.address, web3.utils.toWei("5","ether"), {from: ourTokenCreator});
            expectEvent.inLogs(response.logs, 'RemovedLiquidity', {
                user: ourTokenCreator,
                token: ourTokenInstance.address,
                tokenamount: web3.utils.toWei("5","ether"),
                ethamount: web3.utils.toWei("5","ether"),
            });

            // check contract balance
            assert.equal(await web3.eth.getBalance(simpleExchange.address), web3.utils.toWei("0","ether"), "Expected ether balance in contract");

            //check for lptoken balance
            assert.equal(await lpTokenInstance.balanceOf(ourTokenCreator), web3.utils.toWei("0","ether"), "Expected ether balance in contract");
        });


        it("Check for swaping ETH to buy tokens", async () => {
            //init
            let ourTokenInstance = await OurERC20.new(supply,{from: ourTokenCreator});
            let lpTokenInstance = await ExchangeLPToken.new();
            let simpleExchange =  await SimpleExchange.new(lpTokenInstance.address);
            
            //pre-condition
            await ourTokenInstance.approve(simpleExchange.address, web3.utils.toWei("10","ether"),{from: ourTokenCreator} );
            await lpTokenInstance.passMinterBurnerRole(simpleExchange.address);
            
            // add liquidity
            await simpleExchange.addLiquidity(ourTokenInstance.address, web3.utils.toWei("10","ether"), {from: ourTokenCreator, value: web3.utils.toWei("10","ether")});

            // Buying tokens
            let response = await simpleExchange.ethToToken0Token(ourTokenInstance.address, web3.utils.toWei("0.9","ether"), {from: tokenBuyer, value: web3.utils.toWei("1","ether")});
            // await debug (simpleExchange.ethToToken0Token(ourTokenInstance.address, web3.utils.toWei("0.9","ether"), {from: tokenBuyer, value: web3.utils.toWei("1","ether")}));
            
            
            expectEvent.inLogs(response.logs, 'BoughtTokens', {
                user: tokenBuyer,
                token: ourTokenInstance.address,
                tokenamount: web3.utils.toWei("0.900818926296633303","ether"),
                ethamount: web3.utils.toWei("1","ether"),
            });

            // check contract balance
            assert.equal(await web3.eth.getBalance(simpleExchange.address), web3.utils.toWei("11","ether"), "Expected ether balance in contract");

            //check for lptoken balance
            assert.equal(await ourTokenInstance.balanceOf(tokenBuyer), web3.utils.toWei("0.900818926296633303","ether"), "Expected ether balance in contract");

            // Buy again , for 1 ETH, check for the value you get
            response = await simpleExchange.ethToToken0Token(ourTokenInstance.address, web3.utils.toWei("0.7","ether"), {from: tokenBuyer, value: web3.utils.toWei("1","ether")});
            
            expectEvent.inLogs(response.logs, 'BoughtTokens', {
                user: tokenBuyer,
                token: ourTokenInstance.address,
                tokenamount: web3.utils.toWei("0.751308529021378901","ether"),
                ethamount: web3.utils.toWei("1","ether"),
            });

            // check contract balance
            assert.equal(await web3.eth.getBalance(simpleExchange.address), web3.utils.toWei("12","ether"), "Expected ether balance in contract");

            console.log((await ourTokenInstance.balanceOf(tokenBuyer)).toString())

            //check for lptoken balance
            assert.equal(await ourTokenInstance.balanceOf(tokenBuyer), web3.utils.toWei("1.652127455318012204","ether"), "Expected ether balance in contract");
        });
});