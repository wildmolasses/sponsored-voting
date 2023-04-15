// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "test/SponsoredGovernor.sol";
import "test/GovernanceToken.sol";

// import "lib/account-abstraction/contracts/samples/SimpleAccountFactory.sol";

contract Deploy is Script {
  function setUp() public {}

  function run(address _account1) public {
    IEntryPoint entryPoint = IEntryPoint(0x0576a174D229E3cFA37253523E645A78A0C91B57);
    vm.startBroadcast();
    GovernanceToken _govToken = new GovernanceToken();
    SponsoredGovernor _gov = new SponsoredGovernor{value: .1 ether}(
            "Governor with sponsored voting",
            _govToken,
            entryPoint
        );
    // SimpleAccount account1 = _saf.createAccount(msg.sender, 693178137687136);
    _govToken.mint(address(_account1), 10 ether);
    // vm.prank(address(account1));
    // _govToken.delegate(address(account1));
    // proposal = _getSimpleProposal();
    console.log("gov token", address(_govToken));
    console.log("governor", address(_gov));
    console.log("simple account", address(_account1));
  }
}
