// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/*
* @title PiggyBank
* @author 0xNicos
* @dev 
* @nottice do  not use for production ensure its audited and battle tested.
*/

contract PiggyBank is ReentrancyGuard {
    //_______________
    // Errors
    //_______________

    error PiggyBank__DepositFailed(address sender, uint256 threshold);
    error PiggyBank__ThresholdNotMeet(uint256 threshold);
    error PiggyBank__Unauthorised(address caller);
    error PiggyBank__InsufficentBalance(uint256 balance);
    error PiggyBank__WithdrawFailed(uint256 value);
    error PiggyBank__AlreadyInitailised();
    error PiggyBank__ProtocolFeeFailed(address sender, uint256 protocolFee);

    //_________________
    // State Varaibles
    //_________________
    bool private _initialised;

    address private _owner;
    address private _protocolAddress;
    address[] private _depositors;

    uint256 private constant MINIMUM_THRESHOLD = 0.005 ether;
    uint256 private constant PROTOCOL_FEE_RATE = 30;
    uint256 private constant BASIS_POINT = 10000;

    mapping(address => uint256) private _balanceOf;
    mapping(address => bool) private _isDepositor;

    //_______________
    // Events
    //_______________

    event PiggyBankDeposited(address indexed sender, uint256 indexed value, uint256 time);
    event PiggyBankWihdrawal(address indexed sender, uint256 indexed value, uint256 time);
    event PiggyBankInitialised(address indexed owner, address indexed protocolAddress, uint256 time);

    //_______________
    // Modifier
    //_______________

    modifier minimumHolding() {
        _checkHolding();
        _;
    }

    modifier depositors() {
        _checkDepositors();
        _;
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }
	
	constructor() {
		_initialised = true;
	}

    //_________________
    // Funtion calls
    //_________________

    function initialize(address owner, address protocolAddress) external {
        require(owner != address(0), "Invalid Owner");
        require(protocolAddress != address(0), "Invalid Address");
		if (_initialised) revert PiggyBank__AlreadyInitailised();

        _initialised = true;
        _owner = owner;
        _protocolAddress = protocolAddress;

        emit PiggyBankInitialised(owner, protocolAddress, block.timestamp);
    }

    function deposit() public payable minimumHolding nonReentrant {
        if (msg.value < MINIMUM_THRESHOLD) {
            revert PiggyBank__DepositFailed(_msgSender(), MINIMUM_THRESHOLD);
        }

        uint256 protocolFee = msg.value * PROTOCOL_FEE_RATE / BASIS_POINT;

        _updateDepositors(protocolFee);

        (bool success,) = payable(_protocolAddress).call{value: protocolFee}("");
        if (!success) {
            revert PiggyBank__ProtocolFeeFailed(_msgSender(), protocolFee);
        }

        emit PiggyBankDeposited(_msgSender(), msg.value - protocolFee, block.timestamp);
    }

    function withdraw(uint256 value) external depositors nonReentrant {
        if (_balances() < value) {
            revert PiggyBank__InsufficentBalance(_balances());
        }

        _balanceOf[_msgSender()] -= value;
        _withdrawUpdate();

        (bool success,) = _msgSender().call{value: value}("");
        if (!success) {
            revert PiggyBank__WithdrawFailed(value);
        }

        emit PiggyBankWihdrawal(_msgSender(), value, block.timestamp);
    }

    function updateProtocolAddress(address newProtocolAddress) public onlyOwner {
        require(newProtocolAddress != address(0), "Invalid Address");

        _protocolAddress = newProtocolAddress;
    }

    function updateOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid Owner");

        _owner = newOwner;
    }

    function _updateDepositors(uint256 protocolFee) internal {
        if (!_isDepositor[_msgSender()]) {
            _isDepositor[_msgSender()] = true;
            _depositors.push(payable(_msgSender()));
        }

        uint256 value = msg.value - protocolFee;

        _balanceOf[_msgSender()] += value;
    }

    function _withdrawUpdate() internal {
        for (uint256 i = 0; i < _depositors.length; i++) {
            if (_balances() == 0) {
                if (_depositors[i] == _msgSender()) {
                    uint256 lastIndex = _depositors.length - 1;
                    _depositors[i] = _depositors[lastIndex];

                    _depositors.pop();

                    _isDepositor[_msgSender()] = false;

                    break;
                }
            }
        }
    }

    function _checkOwner() internal view {
        if (_owner != _msgSender()) {
            revert PiggyBank__Unauthorised(_msgSender());
        }
    }

    function _checkDepositors() internal view {
        if (!_isDepositor[_msgSender()]) {
            revert PiggyBank__Unauthorised(_msgSender());
        }
    }

    function _checkHolding() internal view {
        address sender = _msgSender();

        if (sender.balance < MINIMUM_THRESHOLD) {
            revert PiggyBank__ThresholdNotMeet(MINIMUM_THRESHOLD);
        }
    }

    function _msgSender() internal view returns (address) {
        return msg.sender;
    }

    function _balances() internal view returns (uint256) {
        uint256 balance = _balanceOf[_msgSender()];
        return balance;
    }

    //_________________
    // Getters Functions
    //_________________

    function getOwner() external view returns (address) {
        return _owner;
    }

    function getProtocolAddr() external view returns (address) {
        return _protocolAddress;
    }

    function getIntilaised() external view returns (bool) {
        return _initialised;
    }

    function getMinimumThreshold() external pure returns (uint256) {
        return MINIMUM_THRESHOLD;
    }

    function getDepositorBalance(address depositor) external view returns (uint256) {
        return _balanceOf[depositor];
    }

    function getDepositorStatus(address depositor) external view returns (bool) {
        return _isDepositor[depositor];
    }

    function getDepositorsList() external view returns (address[] memory) {
        return _depositors;
    }
}
