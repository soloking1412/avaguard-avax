// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AvaGuardCircuitBreaker {
    address public owner;
    bool public paused;

    uint256 public maxTVL;
    uint256 public maxMintPerBlock;
    uint256 public maxPriceDeviationBps;

    event Paused(string reason);
    event Unpaused();
    event ThresholdsUpdated(uint256 maxTVL, uint256 maxMintPerBlock, uint256 maxPriceDeviationBps);
    event InvariantChecked(bool passed, uint256 tvl, uint256 mint, uint256 deviationBps);

    error NotOwner();
    error ProtocolPaused();
    error ZeroMaxTVL();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier notPaused() {
        if (paused) revert ProtocolPaused();
        _;
    }

    constructor(
        uint256 _maxTVL,
        uint256 _maxMintPerBlock,
        uint256 _maxPriceDeviationBps
    ) {
        if (_maxTVL == 0) revert ZeroMaxTVL();
        owner = msg.sender;
        maxTVL = _maxTVL;
        maxMintPerBlock = _maxMintPerBlock;
        maxPriceDeviationBps = _maxPriceDeviationBps;
    }

    function checkAndPause(
        uint256 currentTVL,
        uint256 currentMintAmount,
        uint256 currentDeviationBps
    ) external {
        bool breached = (
            currentTVL > maxTVL ||
            currentMintAmount > maxMintPerBlock ||
            currentDeviationBps > maxPriceDeviationBps
        );

        if (breached && !paused) {
            paused = true;
            emit Paused(_reason(currentTVL, currentMintAmount, currentDeviationBps));
        }

        emit InvariantChecked(!breached, currentTVL, currentMintAmount, currentDeviationBps);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused();
    }

    function updateThresholds(
        uint256 _maxTVL,
        uint256 _maxMintPerBlock,
        uint256 _maxPriceDeviationBps
    ) external onlyOwner {
        if (_maxTVL == 0) revert ZeroMaxTVL();
        maxTVL = _maxTVL;
        maxMintPerBlock = _maxMintPerBlock;
        maxPriceDeviationBps = _maxPriceDeviationBps;
        emit ThresholdsUpdated(_maxTVL, _maxMintPerBlock, _maxPriceDeviationBps);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }

    function _reason(
        uint256 tvl,
        uint256 mint,
        uint256
    ) internal view returns (string memory) {
        if (tvl > maxTVL) return "TVL threshold exceeded";
        if (mint > maxMintPerBlock) return "mint-per-block threshold exceeded";
        return "price deviation threshold exceeded";
    }
}
