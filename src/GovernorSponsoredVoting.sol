// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {BasePaymaster} from "lib/account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

error NotSponsored(bytes4 selector);

abstract contract GovernorSponsoredVoting is Governor, GovernorCountingSimple, BasePaymaster {
  mapping(bytes4 => bool) sponsoredFunctions;

  constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
    sponsoredFunctions[Governor.castVote.selector] = true;
    sponsoredFunctions[Governor.castVoteWithReason.selector] = true;
    sponsoredFunctions[Governor.castVoteWithReasonAndParams.selector] = true;
    sponsoredFunctions[Governor.castVoteBySig.selector] = true;
    sponsoredFunctions[Governor.castVoteWithReasonAndParamsBySig.selector] = true;
    // TODO: sponsor execution
  }

  /**
   * @dev Mapping from proposal ID to vote tallies for that proposal.
   */
  mapping(uint256 => ProposalVote) private _proposalVotes;

  /**
   * @dev Mapping from proposal ID and address to the weight the address
   * has cast on that proposal, e.g. _proposalVotersWeightCast[42][0xBEEF]
   * would tell you the number of votes that 0xBEEF has cast on proposal 42.
   */
  mapping(uint256 => mapping(address => uint128)) private _proposalVotersWeightCast;

  // // solhint-disable-next-line func-name-mixedcase
  // function COUNTING_MODE()
  //     public
  //     pure
  //     virtual
  //     override
  //     returns (string memory)
  // {
  //     return "support=bravo&quorum=for,abstain";
  // }

  // /**
  //  * @dev See {IGovernor-hasVoted}.
  //  */
  // function hasVoted(
  //     uint256 proposalId,
  //     address account
  // ) public view virtual override returns (bool) {
  //     return _proposalVotersWeightCast[proposalId][account] > 0;
  // }

  /**
   * payment validation: check if paymaster agrees to pay.
   * // Must verify sender is the entryPoint.
   * Revert to reject this request.
   * Note that bundlers will reject this method if it changes the state, unless the paymaster is
   * trusted (whitelisted)
   * The paymaster pre-pays using its deposit, and receive back a refund after the postOp method
   * returns.
   * @param userOp the user operation
   * @param userOpHash hash of the user's request data.
   * @param maxCost the maximum cost of this transaction (based on maximum gas and gas price from
   * userOp)
   * @return context value to send to a postOp
   *      zero length to signify postOp is not required.
   * @return validationData signature and time-range of this operation, encoded the same as the
   * return value of validateUserOperation
   *      <20-byte> sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
   *         otherwise, an address of an "authorizer" contract.
   *      <6-byte> validUntil - last timestamp this operation is valid. 0 for "indefinite"
   *      <6-byte> validAfter - first timestamp this operation is valid
   *      Note that the validation code cannot use block.timestamp (or block.number) directly.
   */
  function _validatePaymasterUserOp(
    UserOperation calldata userOp,
    bytes32 userOpHash,
    uint256 maxCost
  ) internal virtual override returns (bytes memory context, uint256 validationData) {
    /**
     * User Operation struct
     * @param sender the sender account of this request.
     * @param nonce unique value the sender uses to verify it is not a replay.
     * @param initCode if set, the account contract will be created by this constructor/
     * @param callData the method call to execute on this account.
     * @param callGasLimit the gas limit passed to the callData method call.
     * @param verificationGasLimit gas used for validateUserOp and validatePaymasterUserOp.
     * @param preVerificationGas gas not calculated by the handleOps method, but added to the gas
     * paid. Covers batch overhead.
     * @param maxFeePerGas same as EIP-1559 gas parameter.
     * @param maxPriorityFeePerGas same as EIP-1559 gas parameter.
     * @param paymasterAndData if set, this field holds the paymaster address and paymaster-specific
     * data. the paymaster will pay for the transaction instead of the sender.
     * @param signature sender-verified signature over the entire request, the EntryPoint address
     * and the chain ID.
     */
    // TODO:
    // check userOp.maxFeePerGas, userOp.maxPriorityFeeePerGas to ensure sane values
    // check userOp.callGasLimit to ensure sane value
    // check method call to ensure it's of a certain subset of values
    // revert to reject
    bytes4 selector = bytes4(userOp.callData[:4]);
    if (!sponsoredFunctions[selector]) revert NotSponsored(selector);
  }

  // TODO: Add initializer that sets EntryPoint (should EntryPoint be mutable?)
}
