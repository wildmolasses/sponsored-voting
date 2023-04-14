// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {GovernorSponsoredVoting} from "src/GovernorSponsoredVoting.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract SponsoredGovernor is GovernorVotes, GovernorSponsoredVoting {
    constructor(
        string memory _name,
        IVotes _token,
        IEntryPoint _entryPoint
    )
        GovernorVotes(_token)
        GovernorSponsoredVoting(_entryPoint)
        Governor(_name)
    {}

    function quorum(uint256) public pure override returns (uint256) {
        return 10 ether;
    }

    function votingDelay() public pure override returns (uint256) {
        return 4;
    }

    function votingPeriod() public pure override returns (uint256) {
        return 50_400; // 7 days assuming 12 second block times
    }
}
