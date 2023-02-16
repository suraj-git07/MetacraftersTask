// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.15;

// FundToken is our Native Dapp ERC20 Token
import "./FundToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CrowdFunding is ReentrancyGuard {
    // State Variables

    address public owner; // owner of FundToken
    address payable contAdd = payable(address(this)); // Croundfunding Contract Address
    uint public valueTobuyToken; // Value of Token
    mapping(address => uint) public contributors; // contributers and their contribution
    uint public noOfContributors; // no of contributers

    uint256 constant DECIMALS = 18;

    enum Status {
        RUNNING,
        APPROVED,
        FAILED,
        END
    }

    // STRUCTURES

    struct Goal {
        string description;
        address payable recipient;
        uint deadline;
        uint target;
        uint value;
        Status status;
        uint noOfVoters;
        mapping(address => uint) contribution;
        mapping(address => bool) claimed;
    }

    struct OwnerRequest {
        address to;
        uint amt;
        uint reqId;
        bool status;
    }

    // EVENTS

    event GoalCreated(
        string desc,
        address indexed recipient,
        uint deadline,
        uint target
    );

    event TokenBought(address indexed buyer, uint how_much);

    event FundedGoal(address indexed who, uint goalId, uint amtOftoken);

    event FundClaimed(address indexed who, uint goalId, uint value, uint when);

    event ClaimedRefund(address indexed who, uint goalId, uint value);

    event OwnerReqested(address indexed to, uint amt, uint reqId);

    event ReqestSettled(address indexed to, uint amt, uint reqId);

    // Mappings and State Variables

    OwnerRequest[] public ownerRequests;
    uint public fullfillrequests;
    uint public noOfOwnerRequests;

    mapping(uint => Goal) public goals;
    uint public numGoals;

    // instance of Fund Token
    FundToken public fundToken;

    //MODIFIERS

    // check if the requested goal ID is valid or not
    modifier validGoal(uint _goalId) {
        require(_goalId >= 0 && _goalId < numGoals, "Goal is not Valid");
        _;
    }

    // Only owner can call
    modifier Onlyowner() {
        require(msg.sender == owner, "only owner can call the function");
        _;
    }

    constructor(FundToken _fundToken, uint _valueOfToken) {
        fundToken = _fundToken;
        owner = msg.sender;
        valueTobuyToken = _valueOfToken; // in wei
    }

    // FUNCTIONS

    // function to create a goal with specific requirements
    function createGoal(
        string memory _description,
        address payable _recipient,
        uint _deadline,
        uint _target
    ) public {
        require(_deadline > block.timestamp, "deadline is already ended");
        require(_target > 0, "target required cannot be negative");
        Goal storage newGoal = goals[numGoals];
        numGoals++;
        newGoal.description = _description;
        newGoal.recipient = _recipient;
        newGoal.deadline = _deadline;
        newGoal.target = _target * (10 ** DECIMALS);
        newGoal.status = Status.RUNNING;
        newGoal.value = 0;
        newGoal.noOfVoters = 0;
        emit GoalCreated(_description, _recipient, _deadline, _target);
    }

    // buy fundToken
    function buyFundToken(
        uint _amtOftoken
    ) public payable nonReentrant returns (bool) {
        require(_amtOftoken > 0, "required amount should be positive");
        require(
            msg.value >= (_amtOftoken * (valueTobuyToken)),
            "not have enough balance"
        );

        OwnerRequest memory newreq;
        newreq.amt = _amtOftoken * (10 ** (DECIMALS));
        newreq.reqId = noOfOwnerRequests;
        newreq.status = false;
        newreq.to = msg.sender;
        ownerRequests.push(newreq);
        noOfOwnerRequests++;

        uint returnvalue = msg.value - (_amtOftoken * (valueTobuyToken));
        if (returnvalue > 0) {
            address payable buyer = payable(msg.sender);
            buyer.transfer(returnvalue);
        }
        emit TokenBought(msg.sender, _amtOftoken);
        emit OwnerReqested(msg.sender, newreq.amt, newreq.reqId);
        return true;
    }

    //fund any goal
    function fundGoal(
        uint _goalId,
        uint _amtOfToken
    ) public validGoal(_goalId) {
        require(_amtOfToken > 0, "value cannot be negative");
        Goal storage currgoal = goals[_goalId];
        require(currgoal.deadline > block.timestamp, "goal request is ended");
        uint _value = _amtOfToken * (10 ** DECIMALS);
        fundToken.transferFrom(msg.sender, owner, _value);
        currgoal.value += _amtOfToken * (10 ** DECIMALS);
        if (contributors[msg.sender] == 0) {
            noOfContributors++;
            currgoal.noOfVoters++;
        }
        currgoal.contribution[msg.sender] += _amtOfToken * (10 ** DECIMALS);
        contributors[msg.sender] += _amtOfToken * (10 ** DECIMALS);

        currgoal.noOfVoters++;
        if (currgoal.value > currgoal.target) {
            currgoal.status = Status.APPROVED;
        }

        emit FundedGoal(msg.sender, _goalId, _amtOfToken);
    }

    // claim fund after the deadline is ended and Goal is achieved
    function claimGoalFund(
        uint _goalId
    ) external validGoal(_goalId) nonReentrant {
        Goal storage currgoal = goals[_goalId];
        require(
            currgoal.recipient == msg.sender,
            "You are not the owner of Goal"
        );
        require(currgoal.status != Status.END, "goal is ended");
        require(
            currgoal.deadline <= block.timestamp,
            "funding is still in process"
        );
        require(currgoal.status == Status.APPROVED, "Your Goal is not achived");

        OwnerRequest memory newreq;
        newreq.amt = currgoal.value;
        newreq.reqId = noOfOwnerRequests;
        newreq.status = false;
        newreq.to = msg.sender;
        ownerRequests.push(newreq);

        noOfOwnerRequests++;
        currgoal.status = Status.END;

        emit FundClaimed(msg.sender, _goalId, currgoal.value, block.timestamp);
        emit OwnerReqested(msg.sender, newreq.amt, newreq.reqId);
    }

    // If the goal you funded rejected you can claim the funds back after the deadline
    function claimRefund(
        uint _goalId
    ) external validGoal(_goalId) nonReentrant {
        Goal storage currgoal = goals[_goalId];
        uint contri = currgoal.contribution[msg.sender];
        require(
            currgoal.deadline <= block.timestamp,
            "funding is still in process"
        );
        require(
            currgoal.status != Status.APPROVED,
            "goal is Approved no Refund"
        );
        require(contri > 0, "You are not a contributer to this goal");
        require(currgoal.claimed[msg.sender] == false, "already claimed");

        OwnerRequest memory newreq;
        newreq.amt = contri;
        newreq.reqId = noOfOwnerRequests;
        newreq.status = false;
        newreq.to = msg.sender;
        ownerRequests.push(newreq);

        noOfOwnerRequests++;

        currgoal.claimed[msg.sender] = true;

        emit ClaimedRefund(msg.sender, _goalId, contri);
        emit OwnerReqested(msg.sender, newreq.amt, newreq.reqId);
    }

    // Settle requests of token transfers in one go by the owner of fundtokens
    function settleRequests() external Onlyowner {
        uint totalReq = noOfOwnerRequests; // if 5 means 0-4 req
        uint fullfill = fullfillrequests; // till which index request is fullfill initial is -1 so we need to fullfill req from 0 to 4
        for (fullfill; fullfill < totalReq; fullfill++) {
            OwnerRequest storage currreq = ownerRequests[fullfill];
            uint256 amt = currreq.amt;
            fundToken.transferFrom(owner, currreq.to, amt);
            emit ReqestSettled(currreq.to, amt, fullfill);
            currreq.status = true;
        }

        fullfillrequests = fullfill;
    }

    // get and set status for Rejection
    function setStatus(
        uint _goalId
    ) public validGoal(_goalId) returns (Status) {
        Goal storage currgoal = goals[_goalId];

        if (
            currgoal.deadline < block.timestamp &&
            currgoal.status != Status.APPROVED
        ) {
            currgoal.status = Status.FAILED;
        }

        return currgoal.status;
    }
}
