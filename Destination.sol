// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./BridgeToken.sol";

contract Destination is AccessControl {
    bytes32 public constant WARDEN_ROLE = keccak256("BRIDGE_WARDEN_ROLE");
    bytes32 public constant CREATOR_ROLE = keccak256("CREATOR_ROLE");

    // Mapping: underlying => wrapped
    mapping(address => address) public wrapped_tokens;
    // Mapping: wrapped => underlying
    mapping(address => address) public underlying_tokens;
    // List of all wrapped token addresses
    address[] private tokens;

    // 修正事件参数名称，与测试预期匹配
    event Creation(address indexed underlying_token, address indexed wrapped_token);
    event Wrap(
        address indexed underlying_token,
        address indexed wrapped_token,
        address to,
        uint256 amount
    );
    event Unwrap(
        address indexed underlying_token,
        address indexed wrapped_token,
        address frm,  // 测试预期的参数名称是frm而非from
        address to,
        uint256 amount
    );

    constructor(address admin) {
        require(admin != address(0), "Admin address cannot be zero");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(CREATOR_ROLE, admin);
        _grantRole(WARDEN_ROLE, admin);
    }

    /// @notice Create a new wrapped token for the given underlying token.
    function createToken(address underlying, string memory name, string memory symbol)
        public
        onlyRole(CREATOR_ROLE)
        returns (address)
    {
        require(underlying != address(0), "Underlying cannot be zero address");
        require(wrapped_tokens[underlying] == address(0), "Token already exists");

        BridgeToken wrappedToken = new BridgeToken(underlying, name, symbol, address(this));
        wrappedToken.grantRole(wrappedToken.MINTER_ROLE(), address(this));

        address wrapped = address(wrappedToken);
        wrapped_tokens[underlying] = wrapped; 
        underlying_tokens[wrapped] = underlying;
        tokens.push(wrapped);

        emit Creation(underlying, wrapped);  // 触发事件时使用正确的参数
        return wrapped;
    }

    /// @notice Mint wrapped tokens to `to` address.
    function wrap(address underlying, address to, uint256 amount)
        public
        onlyRole(WARDEN_ROLE)
    {
        require(to != address(0), "Recipient cannot be zero address");
        address wrapped = wrapped_tokens[underlying];
        require(wrapped != address(0), "Token not registered");
        require(underlying_tokens[wrapped] == underlying, "Invalid token mapping");

        BridgeToken(wrapped).mint(to, amount);
        emit Wrap(underlying, wrapped, to, amount);  // 触发事件时使用正确的参数
    }

    /// @notice Burn wrapped tokens from caller and initiate unwrapping process.
    function unwrap(address wrapped, address to, uint256 amount) public {
        require(to != address(0), "Recipient cannot be zero address");
        address underlying = underlying_tokens[wrapped];
        require(underlying != address(0), "Invalid wrapped token");
        require(wrapped_tokens[underlying] == wrapped, "Invalid token mapping");

        BridgeToken(wrapped).burnFrom(msg.sender, amount);
        emit Unwrap(underlying, wrapped, msg.sender, to, amount);  // 触发事件时使用正确的参数
    }

    /// @notice Get all wrapped token addresses
    function getWrappedTokens() external view returns (address[] memory) {
        return tokens;
    }

    /// @notice Get the counterpart token for a given token (either wrapped or underlying)
    function getMapping(address token) external view returns (address) {
        address mapped = underlying_tokens[token];
        if (mapped != address(0)) {
            return mapped;
        }
        return wrapped_tokens[token];
    }
}
