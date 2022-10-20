// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract ExchangeLPToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    constructor() ERC20("ExchangeLPToken","ELPT") {
        _setupRole(DEFAULT_ADMIN_ROLE,msg.sender);
        _setupRole(MINTER_ROLE,msg.sender);
        _setupRole(BURNER_ROLE,msg.sender);

    }

    function mint(address user, uint256 amount) external {
        require(hasRole(MINTER_ROLE, msg.sender),"Does not have the minter role");
        _mint(user,amount);
    }

    function burn(address user, uint256 amount) external {
        require(hasRole(BURNER_ROLE, msg.sender),"Does not have the minter role");
        _burn(user,amount);
    }

    function passMinterBurnerRole(address _newMinter) public {
        grantRole(MINTER_ROLE, _newMinter);
        grantRole(BURNER_ROLE, _newMinter);
    }
}