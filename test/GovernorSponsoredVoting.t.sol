// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "./SponsoredGovernor.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {SimpleAccountFactory} from
  "lib/account-abstraction/contracts/samples/SimpleAccountFactory.sol";
import {SimpleAccount} from "lib/account-abstraction/contracts/samples/SimpleAccount.sol";
import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {GovernanceToken} from "./GovernanceToken.sol";
import {ReceiverMock} from "./ReceiverMock.sol";

contract TestHarness is Test {
  using ECDSA for bytes32;

  EntryPoint entryPoint;
  SimpleAccount account1;
  GovernorSponsoredVoting governor;
  GovernanceToken govToken;
  ReceiverMock receiver;
  Proposal proposal;
  address payable beneficiary;
  uint256 pk = 369;
  address accountOwner = vm.addr(pk);

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
    SimpleAccountFactory _saf = new SimpleAccountFactory(entryPoint);
    account1 = _saf.createAccount(accountOwner, 0);
    vm.label(address(account1), "account 1");
    beneficiary = payable(address(5555));
    vm.label(beneficiary, "beneficiary");
    govToken = new GovernanceToken();
    vm.label(address(govToken), "govToken");
    governor = new SponsoredGovernor("hey", govToken, entryPoint);
    vm.deal(address(governor), 10 ether);
    vm.prank(address(governor));
    // stake to entryPoint
    address(entryPoint).call{value: 1 ether}("");
    govToken.mint(address(account1), 10 ether);
    vm.prank(address(account1));
    govToken.delegate(address(account1));
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

  function _castVotes(SimpleAccount _voter, uint256 _proposalId) internal {
    // assertFalse(governor.hasVoted(_proposalId, _voter.addr));
    uint8 _support = 1;
    vm.expectEmit(true, true, true, true);
    emit VoteCast(address(_voter), _proposalId, 1, govToken.balanceOf(address(_voter)), "");

    // TODO: changing to AA
    // // vm.prank(_voter);
    // // governor.castVote(_proposalId, _support);
    bytes memory _op = abi.encodeWithSelector(governor.castVote.selector, _proposalId, _support);

    bytes memory _executeOp = abi.encodeWithSelector(
      account1.execute.selector,
      address(governor), // dest
      0, // value
      _op // func
    );

    (UserOperation memory _userOp, /* bytes32 _userOpHash */ ) = _createUserOp(_voter, _executeOp);
    UserOperation[] memory _ops = new UserOperation[](1);
    _ops[0] = _userOp;
    entryPoint.handleOps(_ops, beneficiary);
    require(governor.hasVoted(_proposalId, address(_voter)));
  }

  function _createUserOp(SimpleAccount _sender, bytes memory callData)
    public
    view
    returns (UserOperation memory, bytes32)
  {
    UserOperation memory _userOperation;
    _userOperation.sender = address(_sender);
    _userOperation.nonce = _sender.nonce();
    _userOperation.initCode = "";
    _userOperation.callData = callData;
    _userOperation.callGasLimit = 200_000;
    _userOperation.verificationGasLimit = 100_000;
    _userOperation.preVerificationGas = 10_000_000;
    _userOperation.maxFeePerGas = 3e9;
    _userOperation.maxPriorityFeePerGas = 2 gwei;
    _userOperation.paymasterAndData = abi.encodePacked(address(governor));
    // _userOperation.signature = vm.sign()
    bytes32 _userOpHash = entryPoint.getUserOpHash(_userOperation);
    console2.log(accountOwner);
    // bytes32 _digest = keccak256(
    //     abi.encode(_userOpHash, address(entryPoint), block.chainid)
    // ).toEthSignedMessageHash();
    (uint8 _v, bytes32 _r, bytes32 _s) = vm.sign(pk, _userOpHash.toEthSignedMessageHash());
    _userOperation.signature = bytes.concat(_r, _s, bytes1(_v));
    console.logBytes32(_userOpHash);
    return (_userOperation, _userOpHash);
  }
}

contract SmokeTest is TestHarness {
  function test_smoke() public {
    _submitProposal(proposal);
    _castVotes(account1, proposal.id);
    _executeProposal(proposal);
  }
}

// contract GovernanceSponsoredVotingTest is TestHarness {
//     function test_smoke() public {
//         _submitProposal(proposal);
//         _castVotes(account1, proposal.id);
//         _executeProposal(proposal);
//     }
// }
