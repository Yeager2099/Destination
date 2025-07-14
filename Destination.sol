// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    
    mapping(address => address) public underlying_tokens;
    mapping(address => address) public wrapped_tokens;
    address[] public tokens;

    event Creation(address indexed underlying, address indexed wrapped);
    event Wrap(address indexed underlying, address indexed wrapped, address to, uint amount);
    event Unwrap(address indexed underlying, address indexed wrapped, address from, address to, uint amount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    function wrap(address underlying, address to, uint amount) public onlyRole(WARDEN_ROLE) {
        address wrapped = underlying_tokens[underlying];
        require(wrapped != address(0), "Token not registered");
        
        // 双重确认映射关系
        require(wrapped_tokens[wrapped] == underlying, "Invalid token mapping");
        
        BridgeToken(wrapped).mint(to, amount);
        emit Wrap(underlying, wrapped, to, amount);
    }

    function unwrap(address wrapped, address to, uint amount) public onlyRole(WARDEN_ROLE) {
        address underlying = wrapped_tokens[wrapped];
        require(underlying != address(0), "Invalid wrapped token");
        
        // 双重确认映射关系
        require(underlying_tokens[underlying] == wrapped, "Invalid token mapping");
        
        BridgeToken(wrapped).burnFrom(msg.sender, amount);
        emit Unwrap(underlying, wrapped, msg.sender, to, amount);
    }

    function createToken(address underlying, string memory name, string memory symbol) 
        public 
        onlyRole(CREATOR_ROLE) 
        returns(address) 
    {
        require(underlying_tokens[underlying] == address(0), "Token exists");
        
        BridgeToken wrappedToken = new BridgeToken(underlying, name, symbol, address(this));
        
        // 授予必要的角色
        bytes32 minterRole = wrappedToken.MINTER_ROLE();
        wrappedToken.grantRole(minterRole, address(this));
        
        // 更新映射
        underlying_tokens[underlying] = address(wrappedToken);
        wrapped_tokens[address(wrappedToken)] = underlying;
        tokens.push(address(wrappedToken));
        
        emit Creation(underlying, address(wrappedToken));
        return address(wrappedToken);
    }
}
