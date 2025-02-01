// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HCRToken is ERC20, Ownable {
    enum Phase { Expansion, Dilution, Collapse, Rebirth }
    Phase public currentPhase;
    
    uint256 public totalSupplyLimit;
    uint256 public burnRate;
    uint256 public rebirthMultiplier;
    uint256 public lastPhaseChange;
    uint256 public minTimeBetweenPhases = 90 days;
    uint256 public minTradingVolume = 1000000 * 10**18;
    uint256 public requiredVotesPercentage = 50;
    uint256 public governanceRewardPool;

    uint256 public lambda;
    uint256 public alpha;
    uint256 public beta;

    mapping(address => bool) public collapsedParticipants;
    mapping(address => uint256) public lockedTokens;
    mapping(uint256 => uint256) public phaseVotes;
    mapping(address => address) public delegatee;
    mapping(address => bool) public delegateApproval;
    mapping(address => uint256) public delegatedVotes;
    mapping(uint256 => uint256) public proposalEndTime;
    mapping(address => uint256) public pendingL1Transfers;
    mapping(address => uint256) public pendingL2Transfers;
    mapping(address => uint256) public l2Balances;

    struct Proposal {
        string description;
        string parameter;
        uint256 newValue;
        uint256 votesFor;
        uint256 votesAgainst;
        bool executed;
        uint256 endTime;
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCount;

    event TokensBridgedToL2(address indexed user, uint256 amount);
    event TokensBridgedToL1(address indexed user, uint256 amount);
    event PhaseChanged(Phase newPhase);
    event TokensBurned(address indexed user, uint256 amount);
    event TokensRebirthed(address indexed user, uint256 amount);
    event DAOParameterChanged(string parameter, uint256 newValue);
    event TokensLockedForVote(address indexed user, uint256 amount);

    constructor(uint256 _initialSupply, uint256 _totalSupplyLimit) 
        ERC20("HCR-Token", "HCR") 
        Ownable(msg.sender) 
    {
        _mint(msg.sender, _initialSupply);
        totalSupplyLimit = _totalSupplyLimit;
        burnRate = 10;
        rebirthMultiplier = 2;
        currentPhase = Phase.Expansion;
        lastPhaseChange = block.timestamp;
        governanceRewardPool = 1000000 * 10**decimals();
    }

    modifier canProposePhaseChange() {
        require(balanceOf(msg.sender) >= totalSupply() / 20, "Not enough tokens to propose");
        require(block.timestamp >= lastPhaseChange + minTimeBetweenPhases, "Not enough time has passed");
        require(getTradingVolume() >= minTradingVolume, "Trading volume too low for phase change");
        _;
    }

    function confirmBridgeTransfer(uint256 amount, bool toL2) external {
        require(amount > 0, "Amount must be greater than zero");
        if (toL2) {
            require(balanceOf(msg.sender) >= amount, "Insufficient L1 balance");
            pendingL2Transfers[msg.sender] += amount;
        } else {
            require(l2Balances[msg.sender] >= amount, "Insufficient L2 balance");
            pendingL1Transfers[msg.sender] += amount;
        }
    }

    function bridgeToL2(uint256 amount) external {
        require(pendingL2Transfers[msg.sender] >= amount, "Transfer not confirmed");
        _burn(msg.sender, amount);
        l2Balances[msg.sender] += amount;
        pendingL2Transfers[msg.sender] -= amount;
        emit TokensBridgedToL2(msg.sender, amount);
    }

    function bridgeToL1(uint256 amount) external {
        require(pendingL1Transfers[msg.sender] >= amount, "Transfer not confirmed");
        l2Balances[msg.sender] -= amount;
        _mint(msg.sender, amount);
        pendingL1Transfers[msg.sender] -= amount;
        emit TokensBridgedToL1(msg.sender, amount);
    }

    function executeProposal(uint256 proposalId) external {
        Proposal storage proposal = proposals[proposalId];
        require(msg.sender == tx.origin, "Contracts cannot execute proposals");
        require(block.timestamp >= proposal.endTime, "Voting period is not over yet");
        require(!proposal.executed, "Proposal already executed");
        require(proposal.votesFor > proposal.votesAgainst, "Not enough votes in favor");
        
        if (keccak256(bytes(proposal.parameter)) == keccak256(bytes("lambda"))) {
            require(proposal.newValue > 0 && proposal.newValue <= 10, "Invalid lambda value");
            lambda = proposal.newValue;
        } else if (keccak256(bytes(proposal.parameter)) == keccak256(bytes("alpha"))) {
            require(proposal.newValue >= 10 && proposal.newValue <= 100, "Invalid alpha value");
            alpha = proposal.newValue;
        } else if (keccak256(bytes(proposal.parameter)) == keccak256(bytes("beta"))) {
            require(proposal.newValue >= 0 && proposal.newValue <= 50, "Invalid beta value");
            beta = proposal.newValue;
        } else {
            revert("Invalid parameter");
        }
        
        proposal.executed = true;
    }

    function getTradingVolume() public pure returns (uint256) {
        return 1000000 * 10**18;
    }
}
