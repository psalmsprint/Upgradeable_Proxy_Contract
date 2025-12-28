// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Test} from "forge-std/Test.sol";
import {PiggyBank} from "../../src/PiggyBank.sol";
import {Proxy} from "../../src/PiggyBankProxy.sol";
import {DeployPiggyBank} from "../../script/DeployPiggyBank.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {BadProtocolReceiver, BadReceiver} from "./../mocks/BadReceiver.sol";

contract PiggyBantTest is Test {
    DeployPiggyBank deploy;
    HelperConfig helper;
    PiggyBank piggyBank;
	Proxy proxy;

    address owner;
    address protocolAddress;
    uint256 deployerKey;

    address sam = makeAddr("sam");
    address mike = makeAddr("mike");
    address pat = makeAddr("pat");

    uint256 private constant STARTING_USER_BALANCE = 10 ether;
    uint256 private constant PROTOCOL_FEE_RATE = 30;
    uint256 private constant BASIS_POINT = 10000;

    event PiggyBankDeposited(address indexed sender, uint256 indexed value, uint256 time);
    event PiggyBankWihdrawal(address indexed sender, uint256 indexed value, uint256 time);
    event PiggyBankInitialised(address indexed owner, address indexed protocolAddress, uint256 time);
    event ImplementationUpgraded(address indexed newImplementationAddress, uint256 blockNumber);

    function setUp() external {
		deploy = new DeployPiggyBank();
		
		(proxy, helper) = deploy.run();
		
        (owner, protocolAddress, deployerKey) = helper.activeNetworkConfig();
		
		piggyBank = PiggyBank(address(proxy));
		
        vm.deal(sam, STARTING_USER_BALANCE);
        vm.deal(mike, STARTING_USER_BALANCE);
        vm.deal(pat, STARTING_USER_BALANCE);
    }

    //______________________
    // Modifier
    //______________________

    modifier deposited() {
        vm.prank(mike);
        piggyBank.deposit{value: 5 ether}();

        vm.prank(sam);
        piggyBank.deposit{value: 9 ether}();

        vm.prank(pat);
        piggyBank.deposit{value: 9.9 ether}();

        _;
    }
	
	//______________________
	// initialize
	//______________________
	
	function testInitialiseRevertAddressZero() public {
		PiggyBank piggy = new PiggyBank();
		Proxy proxies = new Proxy(owner, address(piggy));
		
		piggy = PiggyBank(address(proxies));
		
		vm.expectRevert("Invalid Owner");
		piggy.initialize(address(0), protocolAddress);
	}
	
	function testInitialiseRevertInvalidProtocolAddress() public {
		PiggyBank piggy = new PiggyBank();
		Proxy proxies = new Proxy(owner, address(piggy));
		
		piggy = PiggyBank(address(proxies));
		
		vm.expectRevert("Invalid Address");
		piggy.initialize(owner, address(0));
	}
	
	function testInitialiseRevertDoubleInitialization() public {
		vm.expectRevert(PiggyBank.PiggyBank__AlreadyInitailised.selector);
		piggyBank.initialize(mike, pat);
	}
	
	function testInitialiseUpdateStateAndEmitEvent() public {
		uint256 minimumThreshold = 0.005 ether;
		PiggyBank piggy = new PiggyBank();
		Proxy proxies = new Proxy(owner, address(piggy));
		
		piggy = PiggyBank(address(proxies));
		
		vm.expectEmit(true, true, false, false);
		emit PiggyBankInitialised(owner, protocolAddress, block.timestamp);
		
		piggy.initialize(owner, protocolAddress);
		
		assertEq(piggy.getOwner(), owner);
		assertEq(piggy.getProtocolAddr(), protocolAddress);
		assert(piggy.getIntilaised() == true);
		assertEq(piggy.getMinimumThreshold(),minimumThreshold);
	}

    //______________________
    // deposit
    //______________________
	
	function testDepositRevertNoneHolders() public {
		address john = makeAddr("john");
		uint256 amount = 0.001 ether;
		uint256 minimumThreshold = 0.005 ether;
		vm.deal(john, amount);
		
		vm.prank(john);
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__ThresholdNotMeet.selector, minimumThreshold));
		piggyBank.deposit{value: amount}();
	}
	
	function testDepositRevertDepositBelowThreshold() public {
		uint256 minimumThreshold = 0.005 ether;
		uint256 amount = 0.0049 ether;
		
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__DepositFailed.selector, mike, minimumThreshold));
		vm.prank(mike);
		piggyBank.deposit{value: amount}();
	}
	
	function testDepositPassedAndEmitEvent() public {
		uint256 amount = 5 ether;
		uint256 protocolFee = amount * PROTOCOL_FEE_RATE / BASIS_POINT;
		uint256 depositedAmount = amount - protocolFee;
		
		vm.expectEmit(true, true, true, false);
		emit PiggyBankDeposited(mike, depositedAmount, block.timestamp);
		
		vm.prank(mike);
		piggyBank.deposit{value: amount}();
	}
	
	function testDepositRevertFailedProtocolFeeTransferToProtocol() public {
		BadProtocolReceiver bad = new BadProtocolReceiver();
		PiggyBank piggy = new PiggyBank();
		Proxy proxies = new Proxy(owner, address(piggy));
		
		piggy = PiggyBank(address(proxies));
		
		piggy.initialize(owner, address(bad));
		
		uint256 amount = 3 ether;
		uint256 protocolFee = amount * PROTOCOL_FEE_RATE / BASIS_POINT;
		
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__ProtocolFeeFailed.selector, pat, protocolFee));
		vm.prank(pat);
		piggy.deposit{value: amount}();
	}
	
	function testDepositPassedUpdateState() public {
		uint256 amount = 5 ether;
		uint256 protocolFee = amount * PROTOCOL_FEE_RATE / BASIS_POINT;
		
		vm.prank(sam);
		piggyBank.deposit{value: amount}();
		
		assertEq(piggyBank.getDepositorBalance(sam), amount - protocolFee);
		assertEq(protocolAddress.balance, protocolFee);
	}
	
	//______________________
	// withdraw
	//______________________
	
	function testWithdrawRevertNoneDepositor() public deposited {
		address junior = makeAddr("junior");
		
		vm.prank(junior);
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__Unauthorised.selector, junior));
		piggyBank.withdraw(6 ether);
	}
	
	function testWithdrawRevertMaliciousInteractions() public deposited {
		uint256 amount = 15 ether;
		
		uint256 balance = piggyBank.getDepositorBalance(mike);
		
		vm.prank(mike);
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__InsufficentBalance.selector, balance));
		piggyBank.withdraw(amount);
	}
	
	function testWithdrawRevertFailedCall() public deposited {
		uint256 amount = 1 ether;
		uint256 protocolFee = amount * PROTOCOL_FEE_RATE / BASIS_POINT;
		uint256 expectedOutput = amount - protocolFee;
		
		BadReceiver bad = new BadReceiver();
		
		vm.deal(address(bad), STARTING_USER_BALANCE);
		
		vm.prank(address(bad));
		piggyBank.deposit{value: amount}();
		
		vm.warp(10 days);
		
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__WithdrawFailed.selector, expectedOutput));
		vm.prank(address(bad));
		piggyBank.withdraw(expectedOutput);
	}
	
	function testWithdrawUpdateAndRemoveDepositorWithNoBalance() public deposited {
		uint256 amount = 1 ether;
		uint256 amount2 = 9.9 ether;
		uint256 protocolFee = amount2 * PROTOCOL_FEE_RATE / BASIS_POINT;
		uint256 protocolFee1 = amount * PROTOCOL_FEE_RATE / BASIS_POINT;
		uint256 expectedOutput = amount2 - protocolFee;
		
		vm.prank(sam);
		piggyBank.withdraw(amount);
		
		vm.prank(pat);
		piggyBank.withdraw(expectedOutput);
		
		uint256 expectedBalance = 9 ether - (amount + protocolFee1);
		
		//assertEq(piggyBank.getDepositorBalance(sam), expectedBalance);
		assert(piggyBank.getDepositorStatus(pat) == false);
		assertEq(piggyBank.getDepositorsList().length, 2);
		assertEq(piggyBank.getDepositorBalance(pat), 0);
	}
	
	function testWithdrawEmitEvent() public deposited{
		uint256 amount = 3 ether;
		
		vm.expectEmit(true, true, true, false);
		emit PiggyBankWihdrawal(mike, amount, block.timestamp);
		
		vm.prank(mike);
		piggyBank.withdraw(amount);
	}
	
	//______________________
	// updateProtocolAddress
	//______________________
	
	function testUpdateProtocolAddressRevertZeroAddress() public deposited {
		vm.prank(owner);
		vm.expectRevert("Invalid Address");
		piggyBank.updateProtocolAddress(address(0)); 
	}
	
	function testUpdateProtocolAddressRevertNoneOwner() public deposited {
				address newProtocolAddr = makeAddr("newProtocolAddr");
		
		vm.prank(mike);
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__Unauthorised.selector, mike));
		piggyBank.updateProtocolAddress(newProtocolAddr);
	}
	
	function testUpdateProtocolAddressUpdateState() public deposited {
		vm.warp(30 days);
		address newProtocolAddr = makeAddr("newProtocolAddr");
		
		vm.prank(owner);
		piggyBank.updateProtocolAddress(newProtocolAddr);
		
		assertEq(piggyBank.getProtocolAddr(), newProtocolAddr);
	}
	
	//______________________
	// UpdateOwner
	//______________________
	
	function testUpdateOwnerRevertZeroAddr() public deposited {
		vm.prank(owner);
		vm.expectRevert("Invalid Owner");
		piggyBank.updateOwner(address(0));
	}
	
	function testUpdateOwnerRevertRandomCaller() public deposited {
		address newOwner = makeAddr("newOwner");
		
		vm.prank(sam);
		vm.expectRevert(abi.encodeWithSelector(PiggyBank.PiggyBank__Unauthorised.selector, sam));
		piggyBank.updateOwner(newOwner);
	}
	
	function testUpdateOwnerUpdateState() public deposited {
		address newOwner = makeAddr("newOwner");
		
		vm.prank(owner);
		piggyBank.updateOwner(newOwner);
		
		assertEq(piggyBank.getOwner(), newOwner);
	}
	
	//______________________
	// Proxy Functions
	//______________________
	
	function testUpgradeImplementationRevertRandomCaller() public {
		address newImplementation = makeAddr("newImplementation");
		
		vm.prank(pat);
		vm.expectRevert(abi.encodeWithSelector(Proxy.PiggyBank__Unauthorized.selector, pat));
		proxy.upgradeImplementation(newImplementation);
	}
	
	function testUpgradeImplementationRevertZeroAddress() public {
		vm.prank(owner);
		vm.expectRevert("Invalid Implementation Address");
		proxy.upgradeImplementation(address(0));
	}
	
	function testUpgradeImplementationRevertEOA() public {
		vm.prank(owner);
		vm.expectRevert("Invalid Implementation Address");
		proxy.upgradeImplementation(mike);
	}
	
	function testUpdateOwnerUpdateStateAndEmitEvent() public {
		BadProtocolReceiver bad = new BadProtocolReceiver();
		
		vm.expectEmit(true, true, true, false);
		emit ImplementationUpgraded(address(bad), block.number);
		
		vm.prank(owner);
		proxy.upgradeImplementation(address(bad));
		
		assertEq(proxy._getImplementation(), address(bad));
		assertEq(proxy._getAdmin(), owner);
	}
	
	//______________________
	// Constructor
	//______________________
	
	function testConstructorUpdateState() public {
		Proxy proxies = new Proxy(owner, address(piggyBank));
		
		assertEq(proxies._getImplementation(), address(piggyBank));
		assertEq(proxies._getAdmin(), owner);
	}

}
