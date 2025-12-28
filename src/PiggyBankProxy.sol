// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

contract Proxy {
    error PiggyBank__Unauthorized(address sender);

	bytes32 private constant IMPLEMENTATION_SLOT = 
		0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
	
	bytes32 private constant ADMIN_SLOT = 
		0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    event ImplementationUpgraded(address indexed newImplementationAddress, uint256 blockNumber);

    constructor(address admin, address implementation) {
       assembly{
		   sstore(IMPLEMENTATION_SLOT, implementation)
		   sstore(ADMIN_SLOT, admin)
	   }
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function upgradeImplementation(address newImplementationAddr) public onlyOwner {
        _upgradeImplementationAddr(newImplementationAddr);

        emit ImplementationUpgraded(newImplementationAddr, block.number);
    }

    fallback() external payable {
		address _implementationAddr = _getImplementation();
		
        require(_implementationAddr != address(0), "Invalid Implementation Address");

        assembly {
            calldatacopy(0, 0, calldatasize())

            let result := delegatecall(gas(), _implementationAddr, 0, calldatasize(), 0, 0)

            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }



    function _Sender() internal view returns (address) {
        return msg.sender;
    }

    function _upgradeImplementationAddr(address newImplementationAddr) internal {
		
        require(newImplementationAddr != address(0), "Invalid Implementation Address");
        require(newImplementationAddr.code.length > 0, "Invalid Implementation Address");
	
        assembly {
			sstore(IMPLEMENTATION_SLOT, newImplementationAddr)
		}
    }

    function _checkOwner() internal view {
        if (_Sender() != _getAdmin()) {
            revert PiggyBank__Unauthorized(_Sender());
        }
    }
	
	function _getImplementation() public view returns (address impl) {
		assembly {
			impl := sload(IMPLEMENTATION_SLOT)
		}
	}
	
	function _getAdmin() public view returns (address admin) {
		assembly {
			admin := sload(ADMIN_SLOT)
		}
	}
}
