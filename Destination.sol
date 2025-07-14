// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    mapping(address => address) public underlying_tokens;
    mapping(address => address) public wrapped_tokens;
    address[] private tokens;

    event Creation(address indexed underlying, address indexed wrapped);
    // ✅ 参数名不要加 _token，否则测试不认
    event Wrap(address indexed underlying, address indexed wrapped, address to, uint amount);
    event Unwrap(address indexed underlying, address indexed wrapped, address from, address to, uint amount);

    constructor(address admin) {
        require(admin != address(0), "Admin address cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    function createToken(address underlying, string memory name, string memory symbol)
        public
        onlyRole(CREATOR_ROLE)
        returns (address)
    {
        require(underlying != address(0), "Underlying cannot be zero address");
        require(underlying_tokens[underlying] == address(0), "Token already exists");

        BridgeToken wrappedToken = new BridgeToken(underlying, name, symbol, address(this));
        wrappedToken.grantRole(wrappedToken.MINTER_ROLE(), address(this));

        address wrapped = address(wrappedToken);
        underlying_tokens[underlying] = wrapped;
        wrapped_tokens[wrapped] = underlying;
        tokens.push(wrapped);

        emit Creation(underlying, wrapped);
        return wrapped;
    }

    function wrap(address underlying, address to, uint amount)
        public
        onlyRole(WARDEN_ROLE)
    {
        require(to != address(0), "Recipient cannot be zero address");
        address wrapped = underlying_tokens[underlying];
        require(wrapped != address(0), "Token not registered");
        require(wrapped_tokens[wrapped] == underlying, "Invalid token mapping");

        BridgeToken(wrapped).mint(to, amount);
        emit Wrap(underlying, wrapped, to, amount);
    }

    function unwrap(address wrapped, address to, uint amount) public {
        require(to != address(0), "Recipient cannot be zero address");
        address underlying = wrapped_tokens[wrapped];
        require(underlying != address(0), "Invalid wrapped token");
        require(underlying_tokens[underlying] == wrapped, "Invalid token mapping");

        BridgeToken(wrapped).burnFrom(msg.sender, amount);
        emit Unwrap(underlying, wrapped, msg.sender, to, amount);
    }

    function getWrappedTokens() external view returns (address[] memory) {
        return tokens;
    }

    function getMapping(address token) external view returns (address) {
        address mapped = underlying_tokens[token];
        if (mapped != address(0)) {
            return mapped;
        }
        return wrapped_tokens[token];
    }
}
