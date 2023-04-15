// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {BasePaymaster} from "lib/account-abstraction/contracts/core/BasePaymaster.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {UserOperation} from "lib/account-abstraction/contracts/interfaces/UserOperation.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

error NotSponsored(bytes4 selector);

abstract contract GovernorSponsoredVoting is Governor, BasePaymaster {
    mapping(bytes4 => bool) sponsoredFunctions;

    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {
        // TODO: should be gasLimits
        sponsoredFunctions[Governor.castVote.selector] = true;
        sponsoredFunctions[Governor.castVoteWithReason.selector] = true;
        sponsoredFunctions[
            Governor.castVoteWithReasonAndParams.selector
        ] = true;
        sponsoredFunctions[Governor.castVoteBySig.selector] = true;
        sponsoredFunctions[
            Governor.castVoteWithReasonAndParamsBySig.selector
        ] = true;
        // TODO: sponsor execution
    }

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
    )
        internal
        virtual
        override
        returns (bytes memory context, uint256 validationData)
    {
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
        // TODO: actually, the selector we'll get is `execute`
        // so we should instead decode execute payload
        // then ensure that sender has not yet voted on this proposal
        // bytes4 selector = bytes4(userOp.callData[:4]);
        // if (!sponsoredFunctions[selector]) revert NotSponsored(selector);
        context = "";
        validationData = uint256(bytes32(bytes.concat(bytes20(0), bytes6(0), bytes6(0))));
    }

    // TODO: Add initializer that sets EntryPoint (think: should EntryPoint be mutable?)
}
