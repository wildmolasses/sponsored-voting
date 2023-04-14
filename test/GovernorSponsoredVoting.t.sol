// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./SponsoredGovernor.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {SimpleAccount} from "lib/account-abstraction/contracts/samples/SimpleAccount.sol";
import {GovernanceToken} from "./GovernanceToken.sol";

contract TestHarness is Test {
  EntryPoint entryPoint;
  SimpleAccount user1;
  GovernorSponsoredVoting governor;
  GovernanceToken govToken;

  function setUp() public {
    entryPoint = new EntryPoint();
    user1 = new SimpleAccount(entryPoint);
    govToken = new GovernanceToken();
    governor = new SponsoredGovernor("hey", govToken, entryPoint);
  }
}

contract GovernorSponsoredVotingTest is TestHarness {}
