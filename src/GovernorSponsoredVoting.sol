// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {BasePaymaster} from "lib/account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {SimpleAccount} from "lib/account-abstraction/contracts/samples/SimpleAccount.sol";
import {GovernorCountingSimple} from
  "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import {BytesLib} from "./lib/BytesLib.sol";

abstract contract GovernorSponsoredVoting is Governor, BasePaymaster {
  using BytesLib for bytes;

  uint256 maxCost;

  constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
    maxCost = 999 ether;
  }

  function setMaxCost(uint256 _maxCost) public onlyGovernance {
    maxCost = _maxCost;
  }

  // TODO: manage blacklist, preventing future votes if user call did not effectively vote!
  // TODO: check voting weight and enforce some threshold to prevent griefing

  /**
   * payment validation: check if paymaster agrees to pay.
   * @param _userOp the user operation
   * @param _maxCost the maximum cost of this transaction (based on maximum gas and gas price from
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
    UserOperation calldata _userOp,
    bytes32, /* userOpHash */
    uint256 _maxCost
  ) internal virtual override returns (bytes memory context, uint256 validationData) {
    // we'll only pay up to maxCost
    // TODO: should we be reading userOp values instead of maxCost?
    require(_maxCost < maxCost);
    // let's decode execute payload
    (address _governor, uint256 _value, bytes memory _voteOp) = _decodeExecute(_userOp.callData);
    (uint256 _proposalId, /* uint8 _support */ ) = _decodeCastVote(_voteOp);
    // we only pay for our own votes!
    require(_governor == address(this));
    // don't send us money...
    require(_value == 0);
    // TODO: ensure that proposal is active
    // cannot `require(state(_proposalId) == ProposalState.Active)` because it uses block.number
    // and that voter has weight and not just spamming
    require(getVotes(_userOp.sender, proposalSnapshot(_proposalId)) > 0);
    // and that voter has not yet voted
    require(!hasVoted(_proposalId, _userOp.sender));

    context = "";
    validationData = uint256(
      bytes32(
        bytes.concat(
          bytes20(0), // sigAuthorizer - 0 for valid signature, 1 to mark signature failure,
          // otherwise, an address of an "authorizer" contract.
          // TODO: timestamp should not be valid indefinitely but set to proposal deadline
          bytes6(0), // validUntil - last timestamp this operation is valid. 0 for "indefinite"
          bytes6(0) // validAfter - first timestamp this operation is valid
        )
      )
    );
  }

  function _decodeExecute(bytes calldata _execOp)
    internal
    pure
    returns (address _governor, uint256 _value, bytes memory _op)
  {
    require(bytes4(_execOp[:4]) == SimpleAccount.execute.selector);
    (_governor, _value, _op) = abi.decode(_execOp[4:], (address, uint256, bytes));
  }

  function _decodeCastVote(bytes memory _voteOp)
    internal
    pure
    returns (uint256 _proposalId, uint8 _support)
  {
    require(bytes4(_voteOp.slice(0, 4)) == Governor.castVote.selector);
    (_proposalId, _support) = abi.decode(_voteOp.slice(4, _voteOp.length - 4), (uint256, uint8));
  }

  // TODO: override paymaster methods with modifier `onlyGovernance` rather than `onlyOwner`
  // or, modify BasePaymaster so that it's not tightly coupled with Ownable

  //   /**
  //    * @dev See {BasePaymaster-withdrawTo}.
  //    */
  //   function withdrawTo(address payable withdrawAddress, uint256 amount)
  //     public
  //     override
  //     onlyGovernance
  //   {
  //     entryPoint.withdrawTo(withdrawAddress, amount);
  //   }

  //   /**
  //    * @dev See {BasePaymaster-addStake}.
  //    */
  //   function addStake(uint32 unstakeDelaySec) external payable override onlyGovernance {
  //     entryPoint.addStake{value: msg.value}(unstakeDelaySec);
  //   }

  //   /**
  //    * @dev See {BasePaymaster-unlockStake}.
  //    */
  //   function unlockStake() external override onlyGovernance {
  //     entryPoint.unlockStake();
  //   }

  //   /**
  //    * @dev See {BasePaymaster-withdrawStake}.
  //    */
  //   function withdrawStake(address payable withdrawAddress) external override onlyGovernance {
  //     entryPoint.withdrawStake(withdrawAddress);
  //   }
}
