// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

contract BadProtocolReceiver {
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}

contract BadReceiver {
    receive() external payable {
        revert();
    }

    fallback() external payable {
        revert();
    }
}
