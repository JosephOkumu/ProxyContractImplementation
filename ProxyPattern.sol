// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SimpleProxyPattern
 * @dev A simplified implementation of the EIP-1967 Transparent Proxy Pattern
 * All contracts are combined in a single file for easier understanding
 */

/**
 * @title Implementation (V1)
 * @dev Simple contract that will be the initial implementation behind the proxy
 */
contract Implementation {
    // Storage variables
    uint256 public value;
    bool private initialized;
    address public owner;
    
    // Events
    event ValueChanged(uint256 newValue);
    
    /**
     * @dev Initializer function (replaces constructor in upgradeable contracts)
     * @param initialOwner Address that will own the contract
     */
    function initialize(address initialOwner) public {
        require(!initialized, "Already initialized");
        owner = initialOwner;
        initialized = true;
    }
    
    /**
     * @dev Modifier to restrict functions to the owner
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    /**
     * @dev Updates the stored value
     * @param newValue The new value to store
     */
    function setValue(uint256 newValue) public onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }
    
    /**
     * @dev Returns the contract version
     */
    function getVersion() public pure returns (string memory) {
        return "V1";
    }
}

/**
 * @title ImplementationV2
 * @dev Updated implementation with additional features
 * Notice how storage layout matches V1 to prevent storage collisions
 */
contract ImplementationV2 {
    // Storage variables - must match previous implementation order
    uint256 public value;
    bool private initialized;
    address public owner;
    
    // New storage variables can be added at the end
    string public message;
    
    // Events
    event ValueChanged(uint256 newValue);
    event MessageSet(string newMessage);
    
    /**
     * @dev Initializer function
     * @param initialOwner Address that will own the contract
     */
    function initialize(address initialOwner) public {
        require(!initialized, "Already initialized");
        owner = initialOwner;
        initialized = true;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    function setValue(uint256 newValue) public onlyOwner {
        value = newValue;
        emit ValueChanged(newValue);
    }
    
    /**
     * @dev New function in V2 - sets a message
     * @param newMessage The message to store
     */
    function setMessage(string memory newMessage) public onlyOwner {
        message = newMessage;
        emit MessageSet(newMessage);
    }
    
    /**
     * @dev Returns the contract version
     */
    function getVersion() public pure returns (string memory) {
        return "V2";
    }
}

/**
 * @title ProxyAdmin
 * @dev Contract to manage proxy admin operations
 */
contract ProxyAdmin {
    address public owner;
    
    constructor() {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }
    
    /**
     * @dev Upgrades the implementation of a proxy
     * @param proxy Address of the proxy to upgrade
     * @param newImplementation Address of the new implementation
     */
    function upgrade(address proxy, address newImplementation) external onlyOwner {
        TransparentProxy(proxy).upgradeTo(newImplementation);
    }
    
    /**
     * @dev Transfers ownership of the admin contract
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        owner = newOwner;
    }
}

/**
 * @title TransparentProxy
 * @dev Implementation of the EIP-1967 transparent proxy pattern
 */
contract TransparentProxy {
    // EIP-1967 implementation slot (keccak256("eip1967.proxy.implementation") - 1)
    bytes32 private constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    // EIP-1967 admin slot (keccak256("eip1967.proxy.admin") - 1)
    bytes32 private constant ADMIN_SLOT = 
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    /**
     * @dev Constructor to set up the proxy with initial implementation
     * @param initialImplementation Address of the initial implementation
     * @param initialAdmin Address of the admin
     * @param data Initialization data for the implementation (optional)
     */
    constructor(address initialImplementation, address initialAdmin, bytes memory data) {
        // Set the admin
        _setAdmin(initialAdmin);
        
        // Set the implementation
        _setImplementation(initialImplementation);
        
        // Initialize the implementation if data is provided
        if(data.length > 0) {
            (bool success,) = initialImplementation.delegatecall(data);
            require(success, "Initialization failed");
        }
    }
    
    /**
     * @dev Fallback function to delegate calls to the implementation
     * This is called for all non-admin functions
     */
    fallback() external payable {
        address impl = _getImplementation();
        
        // Execute the delegatecall using assembly
        assembly {
            // Copy msg.data
            calldatacopy(0, 0, calldatasize())
            
            // Delegatecall to the implementation contract
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            
            // Revert or return depending on the delegatecall result
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
    
    /**
     * @dev Receive function to accept ETH
     */
    receive() external payable {}
    
    /**
     * @dev Upgrades the proxy to a new implementation
     * Can only be called by the admin
     * @param newImplementation Address of the new implementation
     */
    function upgradeTo(address newImplementation) public {
        require(msg.sender == _getAdmin(), "Only admin can upgrade");
        _setImplementation(newImplementation);
    }
    
    /**
     * @dev Changes the admin of the proxy
     * Can only be called by the current admin
     * @param newAdmin Address of the new admin
     */
    function changeAdmin(address newAdmin) public {
        require(msg.sender == _getAdmin(), "Only admin can change admin");
        require(newAdmin != address(0), "New admin cannot be zero address");
        _setAdmin(newAdmin);
    }
    
    /**
     * @dev Internal function to get the current implementation
     * @return impl The implementation address
     */
    function _getImplementation() internal view returns (address impl) {
        assembly {
            impl := sload(IMPLEMENTATION_SLOT)
        }
    }
    
    /**
     * @dev Internal function to set the implementation
     * @param newImplementation Address of the new implementation
     */
    function _setImplementation(address newImplementation) internal {
        require(newImplementation != address(0), "Implementation cannot be zero address");
        
        // Check if the implementation is a contract
        uint256 codeSize;
        assembly { codeSize := extcodesize(newImplementation) }
        require(codeSize > 0, "Not a contract");
        
        assembly {
            sstore(IMPLEMENTATION_SLOT, newImplementation)
        }
    }
    
    /**
     * @dev Internal function to get the current admin
     * @return admin The admin address
     */
    function _getAdmin() internal view returns (address admin) {
        assembly {
            admin := sload(ADMIN_SLOT)
        }
    }
    
    /**
     * @dev Internal function to set the admin
     * @param newAdmin Address of the new admin
     */
    function _setAdmin(address newAdmin) internal {
        assembly {
            sstore(ADMIN_SLOT, newAdmin)
        }
    }
}
