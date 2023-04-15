// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract ReceiverMock {
  event MockExecuted();

  function mockExecute() public payable returns (string memory) {
    emit MockExecuted();
    return "Mock Executed";
  }
}
