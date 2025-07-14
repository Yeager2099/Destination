// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    
    // 映射关系
    mapping(address => address) public underlyingToWrapped; // 源链代币 => 包装代币
    mapping(address => address) public wrappedToUnderlying; // 包装代币 => 源链代币

    // 事件
    event Creation(address indexed underlying, address indexed wrapped);
    event Wrap(address indexed underlying, address indexed wrapped, address to, uint amount);
    event Unwrap(address indexed underlying, address indexed wrapped, address from, address to, uint amount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    // 创建包装代币 (仅CREATOR_ROLE可调用)
    function createToken(address underlying, string memory name, string memory symbol) 
        external 
        onlyRole(CREATOR_ROLE) 
        returns (address) 
    {
        require(underlyingToWrapped[underlying] == address(0), "Token already registered");
        
        BridgeToken wrappedToken = new BridgeToken(
            underlying,
            string(abi.encodePacked("Wrapped ", name)),
            string(abi.encodePacked("w", symbol)),
            address(this)
        );
        
        address wrapped = address(wrappedToken);
        underlyingToWrapped[underlying] = wrapped;
        wrappedToUnderlying[wrapped] = underlying;
        
        emit Creation(underlying, wrapped);
        return wrapped;
    }

    // 铸造包装代币 (仅WARDEN_ROLE可调用)
    function wrap(address underlying, address to, uint amount) 
        external 
        onlyRole(WARDEN_ROLE) 
    {
        address wrapped = underlyingToWrapped[underlying];
        require(wrapped != address(0), "Unregistered token");
        
        BridgeToken(wrapped).mint(to, amount);
        emit Wrap(underlying, wrapped, to, amount);
    }

    // 销毁包装代币 (任何人都可调用自己持有的代币)
    function unwrap(address wrapped, address to, uint amount) 
        external 
    {
        address underlying = wrappedToUnderlying[wrapped];
        require(underlying != address(0), "Invalid wrapped token");
        
        BridgeToken(wrapped).burnFrom(msg.sender, amount);
        emit Unwrap(underlying, wrapped, msg.sender, to, amount);
    }
}
