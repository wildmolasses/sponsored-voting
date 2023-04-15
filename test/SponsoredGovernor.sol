// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GovernorSponsoredVoting} from "src/GovernorSponsoredVoting.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

contract SponsoredGovernor is
    GovernorVotes,
    GovernorCountingSimple,
    GovernorSponsoredVoting
{
    constructor(
        string memory _name,
        IVotes _token,
        IEntryPoint _entryPoint
    )
        payable
        GovernorVotes(_token)
        GovernorSponsoredVoting(_entryPoint)
        Governor(_name)
    {
        address(_entryPoint).call{value: msg.value}("");
    }

    function quorum(uint256) public pure override returns (uint256) {
        return 10 ether;
    }

    function votingDelay() public pure override returns (uint256) {
        return 0;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50_400; // 7 days assuming 12 second block times
    }
}
