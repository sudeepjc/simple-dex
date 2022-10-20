//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILPTOKEN is IERC20 {
    function mint(address user, uint256 amount) external ;

    function burn(address user, uint256 amount) external ;
}

contract SimpleExchange {
    ILPTOKEN lpToken; // the liquidity provider token

    mapping(address => uint256) token0ToETHReserve; //in wei

    constructor(address _lpToken) {
        lpToken = ILPTOKEN(_lpToken);
    }

    function getLPReserve() public view returns (uint) {
        return lpToken.balanceOf(address(this));
    }

    function getTokenReserve(address token) public view returns (uint) {
        return IERC20(token).balanceOf(address(this));
    }

    event AddedLiquidity(address user, address token, uint256 tokenamount, uint256 ethamount);
    event RemovedLiquidity(address user, address token, uint256 tokenamount, uint256 ethamount);
    event BoughtTokens(address user, address token, uint256 tokenamount, uint256 ethamount);
    event SoldTokens(address user, address token, uint256 tokenamount, uint256 ethamount);

    function addLiquidity(address token0, uint256 _amount) public payable returns(uint256){
        uint256 liquidity;
        uint256 token0Reserve = getTokenReserve(token0);
        IERC20 token0Contract = IERC20(token0);
        /*
            If the reserve is empty, intake any user supplied value for
            `Ether` and `Token0` tokens because there is no ratio currently
        */
        if(token0Reserve == 0) {
            // Transfer the `Token0` from the user's account to the contract
            token0Contract.transferFrom(msg.sender, address(this), _amount);
            // Take the current ethBalance and mint `ethBalance` amount of LP tokens to the user.
            // `liquidity` provided is equal to `ethBalance` because this is the first time user
            // is adding `Eth` to the contract, so whatever `Eth` contract has is equal to the one supplied
            // by the user in the current `addLiquidity` call
            // `liquidity` tokens that need to be minted to the user on `addLiquidity` call should always be proportional
            // to the Eth specified by the user
            token0ToETHReserve[token0] = msg.value;
            liquidity = token0ToETHReserve[token0];
            emit AddedLiquidity(msg.sender, token0, _amount, msg.value);
            lpToken.mint(msg.sender, liquidity);
        } else {
            /*
                If the reserve is not empty, intake any user supplied value for
                `Ether` and determine according to the ratio how many `Token0` tokens
                need to be supplied to prevent any large price impacts because of the additional
                liquidity
            */
            // EthReserve should be the current ethBalance against that token
            // in the current `addLiquidity` call
            uint ethReserve =  token0ToETHReserve[token0];
            // Ratio should always be maintained so that there are no major price impacts when adding liquidity
            // Ratio here is -> (token0Amount user can add/token0Reserve in the contract) = (Eth Sent by the user/Eth Reserve in the mapping for token);
            // So doing some maths, (token0Amount user can add) = (Eth Sent by the user * token0Reserve /Eth Reserve);
            uint token0Amount = (msg.value * token0Reserve)/(ethReserve);
            require(_amount >= token0Amount, "Amount of tokens sent is less than the minimum tokens required");
            // transfer only (token0Amount user can add) amount of `token0 tokens` from users account
            // to the contract
            token0Contract.transferFrom(msg.sender, address(this), token0Amount);
            // The amount of LP tokens that would be sent to the user should be proportional to the liquidity of
            // ether added by the user
            // Ratio here to be maintained is ->
            // (LP tokens to be sent to the user (liquidity)/ totalSupply of LP tokens in contract) = (Eth sent by the user)/(Eth reserve in the contract)
            // by some maths -> liquidity =  (totalSupply of LP tokens in contract * (Eth sent by the user))/(Eth reserve in the contract)
            liquidity = (lpToken.totalSupply() * msg.value)/ ethReserve;
            lpToken.mint(msg.sender, liquidity);
            token0ToETHReserve[token0] = token0ToETHReserve[token0] + msg.value;
            emit AddedLiquidity(msg.sender, token0, token0Amount, msg.value);
        }
        return liquidity;
    }

    /**
    * @dev Returns the amount Eth/token0 tokens that would be returned to the user
    * in the swap
    */
    function removeLiquidity(address token0, uint _lpAmount) public returns (uint , uint) {
        require(_lpAmount > 0, "_amount should be greater than zero");
        uint ethReserve = token0ToETHReserve[token0];
        uint _totalSupply = lpToken.totalSupply();
        // The amount of Eth that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Eth sent back to the user) / (current Eth reserve for that token)
        // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> (Eth sent back to the user)
        // = (current Eth reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint ethAmount = (ethReserve * _lpAmount)/ _totalSupply;
        // The amount of Token0 token that would be sent back to the user is based
        // on a ratio
        // Ratio is -> (Token0 sent back to the user) / (current Token0 token reserve)
        // = (amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        // Then by some maths -> (Token0 sent back to the user)
        // = (current Token0 token reserve * amount of LP tokens that user wants to withdraw) / (total supply of LP tokens)
        uint token0Amount = (getTokenReserve(token0) * _lpAmount)/ _totalSupply;
        // Burn the sent LP tokens from the user's wallet because they are already sent to
        // remove liquidity
        lpToken.burn(msg.sender, _lpAmount);

        token0ToETHReserve[token0] =  token0ToETHReserve[token0] - ethAmount;
        emit RemovedLiquidity( msg.sender, token0, token0Amount, ethAmount);
        // Transfer `ethAmount` of Eth from the contract to the user's wallet
        payable(msg.sender).transfer(ethAmount);
        // Transfer `token0Amount` of Token0 tokens from the contract to the user's wallet
        IERC20(token0).transfer(msg.sender, token0Amount);
        return (ethAmount, token0Amount);
    }

    /**
    * @dev Returns the amount Eth/Token0 tokens that would be returned to the user
    * in the swap
    */
    function getAmountOfTokens(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        require(inputReserve > 0 && outputReserve > 0, "invalid reserves");
        // We are charging a fee of `1%`
        // Input amount with fee = (input amount - (1*(input amount)/100)) = ((input amount)*99)/100
        uint256 inputAmountWithFee = inputAmount * 99;
        // Because we need to follow the concept of `XY = K` curve
        // We need to make sure (x + Δx) * (y - Δy) = x * y
        // So the final formula is Δy = (y * Δx) / (x + Δx)
        // Δy in our case is `tokens to be received`
        // Δx = ((input amount)*99)/100, x = inputReserve, y = outputReserve
        // So by putting the values in the formulae you can get the numerator and denominator
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = (inputReserve * 100) + inputAmountWithFee;
        return numerator / denominator;
    }

    /**
    * @dev Swaps Eth for token0 Tokens
    */
    function ethToToken0Token(address token0, uint _minTokens) public payable {
        uint256 token0Reserve = getTokenReserve(token0);
        // call the `getAmountOfTokens` to get the amount of Crypto Dev tokens
        // that would be returned to the user after the swap
        // Notice that the `inputReserve` we are sending is equal to
        // token0ToETHReserve[token0] gives the input reserve against that token0
        uint256 tokensBought = getAmountOfTokens(
            msg.value,
            token0ToETHReserve[token0],
            token0Reserve
        );

        require(tokensBought >= _minTokens, "insufficient output amount");
        token0ToETHReserve[token0] =  token0ToETHReserve[token0] + msg.value;
        emit BoughtTokens( msg.sender, token0, tokensBought, msg.value);
        // Transfer the `Token0` tokens to the user
        IERC20(token0).transfer(msg.sender, tokensBought);
    }

    /**
    * @dev Swaps Token0 Tokens for Eth
    */
    function cryptoToken0ToEth(address token0, uint _tokensSold, uint _minEth) public {
        uint256 token0Reserve = getTokenReserve(token0);
        // call the `getAmountOfTokens` to get the amount of Eth
        // that would be returned to the user after the swap
        uint256 ethBought = getAmountOfTokens(
            _tokensSold,
            token0Reserve,
            token0ToETHReserve[token0]
        );
        require(ethBought >= _minEth, "insufficient output amount");
        // Transfer `Token0` tokens from the user's address to the contract
        IERC20(token0).transferFrom(
            msg.sender,
            address(this),
            _tokensSold
        );
        token0ToETHReserve[token0] =  token0ToETHReserve[token0] - ethBought;
        // send the `ethBought` to the user from the contract
        emit SoldTokens(msg.sender,  token0,  _tokensSold,  ethBought);
        payable(msg.sender).transfer(ethBought);
    }
}