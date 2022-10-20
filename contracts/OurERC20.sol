// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract OurERC20 is ERC20 {
    constructor(uint256 _supply) ERC20("OurERC20","O20") {
        _mint(msg.sender, _supply * 10 ** 18);
    }
}