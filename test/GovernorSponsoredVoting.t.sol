// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./SponsoredGovernor.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {SimpleAccount} from "lib/account-abstraction/contracts/samples/SimpleAccount.sol";
import {GovernanceToken} from "./GovernanceToken.sol";
import {ReceiverMock} from "./ReceiverMock.sol";

contract TestHarness is Test {
  EntryPoint entryPoint;
  SimpleAccount user1;
  GovernorSponsoredVoting governor;
  GovernanceToken govToken;
  ReceiverMock receiver;
  Proposal proposal;

  struct Proposal {
    uint256 id;
    address[] targets;
    uint256[] values;
    bytes[] calldatas;
    string description;
  }

  event ProposalCreated(
    uint256 proposalId,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );
  event ProposalExecuted(uint256 proposalId);
  event MockExecuted();
  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 weight, string reason
  );

  function setUp() public {
    entryPoint = new EntryPoint();
    user1 = new SimpleAccount(entryPoint);
    govToken = new GovernanceToken();
    governor = new SponsoredGovernor("hey", govToken, entryPoint);
    govToken.mint(address(user1), 10 ether);
    vm.prank(address(user1));
    govToken.delegate(address(user1));
    receiver = new ReceiverMock();
    proposal = _getSimpleProposal();
  }

  function _getSimpleProposal() internal view returns (Proposal memory) {
    address[] memory targets = new address[](1);
    uint256[] memory values = new uint256[](1);
    bytes[] memory calldatas = new bytes[](1);
    targets[0] = address(receiver);
    values[0] = 0;
    calldatas[0] = abi.encodeWithSignature("mockExecute()");
    string memory description = "mock proposal";
    uint256 proposalId =
      governor.hashProposal(targets, values, calldatas, keccak256(bytes(description)));

    return Proposal(proposalId, targets, values, calldatas, description);
  }

  function _submitProposal(Proposal memory _proposal) internal returns (uint256 proposalId) {
    // proposal will underflow if we're on the zero block
    vm.roll(block.number + 1);

    vm.expectEmit(true, true, true, true);
    emit ProposalCreated(
      _proposal.id,
      address(this),
      _proposal.targets,
      _proposal.values,
      new string[](_proposal.targets.length), // Signatures
      _proposal.calldatas,
      block.number + governor.votingDelay(),
      block.number + governor.votingDelay() + governor.votingPeriod(),
      _proposal.description
    );
    // Submit the proposal.
    proposalId = governor.propose(
      _proposal.targets, _proposal.values, _proposal.calldatas, _proposal.description
    );
    assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

    // Advance proposal to active state.
    vm.roll(governor.proposalSnapshot(proposalId) + 1);
    assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));
  }

  function _executeProposal(Proposal memory _proposal) internal {
    vm.roll(governor.proposalDeadline(_proposal.id) + 1);
    vm.expectEmit(true, true, true, true);
    emit ProposalExecuted(_proposal.id);

    // Ensure that the other contract is invoked.
    vm.expectEmit(true, true, true, true);
    emit MockExecuted();

    governor.execute(
      _proposal.targets,
      _proposal.values,
      _proposal.calldatas,
      keccak256(bytes(_proposal.description))
    );
  }

  function _castVotes(address _voter, uint256 _proposalId) internal {
    // assertFalse(governor.hasVoted(_proposalId, _voter.addr));
    uint8 _support = 1;
    vm.expectEmit(true, true, true, true);
    emit VoteCast(_voter, _proposalId, 1, govToken.balanceOf(_voter), "");

    // TODO: change to AA
    vm.prank(_voter); 
    governor.castVote(_proposalId, _support);

    assertTrue(governor.hasVoted(_proposalId, _voter));
  }
}

contract GovernorSponsoredVotingTest is TestHarness {
  function test_smoke() public {
    _submitProposal(proposal);
    _castVotes(address(user1), proposal.id);
    _executeProposal(proposal);
  }
}
