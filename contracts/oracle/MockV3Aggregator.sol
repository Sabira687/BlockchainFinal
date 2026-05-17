// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockV3Aggregator {
    uint8 public immutable decimals;

    uint80 private roundId;
    int256 private answer;
    uint256 private startedAt;
    uint256 private updatedAt;
    uint80 private answeredInRound;

    constructor(uint8 decimals_, int256 initialAnswer) {
        decimals = decimals_;
        updateAnswer(initialAnswer);
    }

    function updateAnswer(int256 newAnswer) public {
        roundId++;
        answer = newAnswer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId;
    }

    function updateStaleAnswer(int256 newAnswer, uint256 timestamp) external {
        roundId++;
        answer = newAnswer;
        startedAt = timestamp;
        updatedAt = timestamp;
        answeredInRound = roundId;
    }

    function updateIncompleteRound(int256 newAnswer) external {
        roundId++;
        answer = newAnswer;
        startedAt = block.timestamp;
        updatedAt = block.timestamp;
        answeredInRound = roundId - 1;
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 currentRoundId,
            int256 currentAnswer,
            uint256 currentStartedAt,
            uint256 currentUpdatedAt,
            uint80 currentAnsweredInRound
        )
    {
        return (roundId, answer, startedAt, updatedAt, answeredInRound);
    }
}
