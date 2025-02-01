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
    mapping(address => bool) public collapsedParticipants;
    
    // L1 + L2 Bridge (Ethereum + Optimism)
    mapping(address => uint256) public l2Balances;
    event TokensBridgedToL2(address indexed user, uint256 amount);
    event TokensBridgedToL1(address indexed user, uint256 amount);
    
    // DAO-controlled parameters
    uint256 public lambda; // Emission slowdown coefficient
    uint256 public alpha;  // % of tokens sent to pool in Collapse
    uint256 public beta;   // % of tokens burned by DAO
    uint256 public gamma;  // % of tokens converted to next phase
    uint256 public delta;  // Conversion coefficient in Rebirth
    
    event PhaseChanged(Phase newPhase);
    event TokensBurned(address indexed user, uint256 amount);
    event TokensRebirthed(address indexed user, uint256 amount);
    event DAOParameterChanged(string parameter, uint256 newValue);
    
    constructor(uint256 _initialSupply, uint256 _totalSupplyLimit) 
        ERC20("HCR-Token", "HCR") 
        Ownable(msg.sender) 
    {
        _mint(msg.sender, _initialSupply);
        totalSupplyLimit = _totalSupplyLimit;
        burnRate = 10; // Default burn rate (10%)
        rebirthMultiplier = 2; // Default rebirth multiplier
        lambda = 5;  // Default emission slowdown
        alpha = 50;  // 50% of tokens go to the pool in Collapse
        beta = 20;   // 20% of tokens are burned by DAO
        gamma = 30;  // 30% of tokens are converted
        delta = 100; // 100% of converted tokens return in Rebirth
        currentPhase = Phase.Expansion;
    }

    modifier onlyDAO() {
        require(msg.sender == owner(), "Only DAO can change this");
        _;
    }

    function changePhase(Phase newPhase) external onlyDAO {
        require(newPhase != currentPhase, "Already in this phase");
        currentPhase = newPhase;
        emit PhaseChanged(newPhase);
    }

    function updateDAOParameter(string memory parameter, uint256 newValue) external onlyDAO {
        if (keccak256(bytes(parameter)) == keccak256(bytes("lambda"))) {
            lambda = newValue;
        } else if (keccak256(bytes(parameter)) == keccak256(bytes("alpha"))) {
            alpha = newValue;
        } else if (keccak256(bytes(parameter)) == keccak256(bytes("beta"))) {
            beta = newValue;
        } else if (keccak256(bytes(parameter)) == keccak256(bytes("gamma"))) {
            gamma = newValue;
        } else if (keccak256(bytes(parameter)) == keccak256(bytes("delta"))) {
            delta = newValue;
        } else {
            revert("Invalid parameter");
        }
        emit DAOParameterChanged(parameter, newValue);
    }

    function burnTokens(uint256 amount) external {
        require(currentPhase == Phase.Collapse, "Burning allowed only in Collapse phase");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        uint256 burnAmount = (amount * burnRate) / 100;
        _burn(msg.sender, burnAmount);
        collapsedParticipants[msg.sender] = true;
        emit TokensBurned(msg.sender, burnAmount);
    }

    function rebirthTokens() external {
        require(currentPhase == Phase.Rebirth, "Rebirth allowed only in Rebirth phase");
        require(collapsedParticipants[msg.sender], "User didn't participate in Collapse");
        
        uint256 rebirthAmount = (balanceOf(msg.sender) * rebirthMultiplier * delta) / 100;
        require(totalSupply() + rebirthAmount <= totalSupplyLimit, "Rebirth limit reached");
        
        _mint(msg.sender, rebirthAmount);
        collapsedParticipants[msg.sender] = false;
        emit TokensRebirthed(msg.sender, rebirthAmount);
    }

    // L1 to L2 Bridge Mechanism
    function bridgeToL2(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _burn(msg.sender, amount);
        l2Balances[msg.sender] += amount;
        emit TokensBridgedToL2(msg.sender, amount);
    }

    function bridgeToL1(uint256 amount) external {
        require(l2Balances[msg.sender] >= amount, "Insufficient L2 balance");
        l2Balances[msg.sender] -= amount;
        _mint(msg.sender, amount);
        emit TokensBridgedToL1(msg.sender, amount);
    }
}
