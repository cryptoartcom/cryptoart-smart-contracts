// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

contract MockReceiver {
  receive() external payable {
    revert("Always revert");
  }
}