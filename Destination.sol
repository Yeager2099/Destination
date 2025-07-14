// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    // 角色定义
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");
    
    // underlying token (source chain token) => wrapped token (destination chain token)
    mapping(address => address) public underlying_tokens;
    // wrapped token => underlying token
    mapping(address => address) public wrapped_tokens;
    // 所有已创建的wrapped token地址
    address[] public tokens;

    // 事件
    event Creation(address indexed underlying, address indexed wrapped);
    event Wrap(address indexed underlying, address indexed wrapped, address to, uint amount);
    event Unwrap(address indexed underlying, address indexed wrapped, address from, address to, uint amount);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    // 只有拥有Warden角色的账户可以调用，mint新的wrapped token给用户
    function wrap(address underlying, address to, uint amount) public onlyRole(WARDEN_ROLE) {
        address wrapped = underlying_tokens[underlying];
        require(wrapped != address(0), "Token not registered");
        require(wrapped_tokens[wrapped] == underlying, "Invalid token mapping");

        BridgeToken(wrapped).mint(to, amount);
        emit Wrap(underlying, wrapped, to, amount);
    }

    // 允许任意用户销毁自己持有的wrapped token，解锁source链token
    function unwrap(address wrapped, address to, uint amount) public {
        address underlying = wrapped_tokens[wrapped];
        require(underlying != address(0), "Invalid wrapped token");
        require(underlying_tokens[underlying] == wrapped, "Invalid token mapping");

        // 销毁调用者自己的wrapped token，需要调用者提前调用approve
        BridgeToken(wrapped).burnFrom(msg.sender, amount);
        emit Unwrap(underlying, wrapped, msg.sender, to, amount);
    }

    // 只有CREATOR_ROLE可以创建新wrapped token实例
    function createToken(address underlying, string memory name, string memory symbol) 
        public 
        onlyRole(CREATOR_ROLE) 
        returns(address) 
    {
        require(underlying_tokens[underlying] == address(0), "Token exists");

        BridgeToken wrappedToken = new BridgeToken(underlying, name, symbol, address(this));

        // 授予合约自身MINTER_ROLE
        bytes32 minterRole = wrappedToken.MINTER_ROLE();
        wrappedToken.grantRole(minterRole, address(this));

        underlying_tokens[underlying] = address(wrappedToken);
        wrapped_tokens[address(wrappedToken)] = underlying;
        tokens.push(address(wrappedToken));

        emit Creation(underlying, address(wrappedToken));
        return address(wrappedToken);
    }
}
