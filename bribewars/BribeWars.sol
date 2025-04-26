// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.22;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract BribeWar is Ownable, ReentrancyGuard {
    uint256 public incentivizingPeriod;
    uint256 public votingPeriod;
    uint256 public projectCount = 0;
    address public nftContractAddress;
    // uint256 public winnerProjectId;
    struct Briber {
        address briberAddress;
        address tokenAddress;
        uint256 tokenAmnt;
        uint projectId;
    }
    struct NativeBriber {
        address briberAddress;
        uint256 tokenAmnt;
        uint projectId;
    }
    struct Project {
        string name;
        address projectOwner;
        address[] bribers;
        address[] nativeBribers;
        uint256 votes;
    }
    enum govtStatus {
        incentivising,
        voting,
        claiming
    }
    govtStatus internal status = govtStatus.incentivising;
    mapping(address => uint256) public addressVotes;
    uint briberCount = 0;
    uint nativeBriberCount = 0;
    mapping(address => Briber[]) public bribers;
    mapping(address => NativeBriber[]) public nativeBribers;
    uint256 public totalVotes = 0;
    uint256 public lastTokenId = 10;
    mapping(uint256 => bool) public tokenVoted;
    // address[] voterKeys;

    // Project[] public projects;
    mapping(uint256 => Project) public projects;

    // event ProjectIncentivized(uint indexed projectId, address indexed tokenAddress,uint amount);
    event VoteCasted(
        uint indexed projectId,
        address indexed voter,
        uint256 indexed tokenId
    );

    constructor(
        address initialOwner,
        uint256 _incentivizingPeriod,
        uint256 _votingPeriod
    ) Ownable(initialOwner) {
        incentivizingPeriod = block.timestamp + (_incentivizingPeriod * 60* 60 * 24); //* 60 * 24
        votingPeriod = incentivizingPeriod + (_votingPeriod * 60* 60 * 24); //* 60 * 24
    }

    //events
    event briberEvent(
        uint indexed projectId,
        address indexed briber,
        address indexed tokenAddress,
        uint amount
    );
    event nativeBriberEvent(
        uint indexed projectId,
        address indexed briber,
        uint amount
    );

    function initializeProject(string memory _name) public onlyOwner {
        // Project memory tempProject;

        // require(status == govtStatus.incentivising, "cant do it now");
        require(block.timestamp <= incentivizingPeriod, "cant do it now");
        projectCount++;
        //Project[projectCount];
        Project storage newProject = projects[projectCount];
        newProject.name = _name;
        newProject.projectOwner = msg.sender;
        newProject.votes = 0;
    }

    function incentiviseProject(
        uint256 id,
        address _tokenAddress,
        uint256 _tokenAmount
    ) public {
        // require(status == govtStatus.incentivising, "cant do it now");
        require(block.timestamp <= incentivizingPeriod, "cant do it now");

        require(_tokenAmount > 0, "Amount must be greater than 0");
        require(
            IERC20(_tokenAddress).balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient token balance"
        );

        require(
            IERC20(_tokenAddress).transferFrom(
                msg.sender,
                address(this),
                _tokenAmount
            ),
            "transaction failed"
        );
        Project storage newProject = projects[id];
        Briber[] storage tempx = bribers[msg.sender];
        Briber memory temp;
        temp.briberAddress = msg.sender;
        temp.tokenAddress = _tokenAddress;
        temp.tokenAmnt = _tokenAmount;
        temp.projectId = id;
        tempx.push(temp);
        newProject.bribers.push(msg.sender);
        briberCount = briberCount + 1;
        emit briberEvent(id, msg.sender, _tokenAddress, _tokenAmount);
    }
    function incentiviseProject(uint256 id) public payable {
        // require(status == govtStatus.incentivising, "cant do it now");
        require(block.timestamp <= incentivizingPeriod, "cant do it now");

        require(msg.value > 0, "Amount must be greater than 0");
        Project storage newProject = projects[id];
        NativeBriber[] storage tempx = nativeBribers[msg.sender];
        NativeBriber memory temp;
        temp.briberAddress = msg.sender;
        // temp.tokenAddress = address("nativeToken");
        temp.tokenAmnt = msg.value;
        temp.projectId = id;
        tempx.push(temp);
        newProject.nativeBribers.push(msg.sender);
        nativeBriberCount = nativeBriberCount + 1;
        emit nativeBriberEvent(id, msg.sender, msg.value);
    }

    function vote(uint256 _projectId, uint256 tokenId) public {
        // require(status == govtStatus.voting, "cant do it now");
        require(
            block.timestamp >= incentivizingPeriod &&
                block.timestamp <= votingPeriod,
            "cant do it now"
        );

        require(projectCount >= _projectId, "aout of order no");
        require(
            IERC721(nftContractAddress).balanceOf(msg.sender) > 0,
            "dont own the nft"
        );

        Project storage newProject = projects[_projectId];
        require(
            addressVotes[msg.sender] <
                IERC721(nftContractAddress).balanceOf(msg.sender),
            "can cast more vote"
        );
        require(
            IERC721(nftContractAddress).ownerOf(tokenId) == msg.sender,
            "not owner of nft"
        );
        require(!tokenVoted[tokenId], "Token already voted");

        addressVotes[msg.sender]++;
        newProject.votes++;
        totalVotes++;
        tokenVoted[tokenId] = true;

        emit VoteCasted(_projectId, msg.sender, tokenId);
    }
    function changelastTokenId(uint256 _id) external onlyOwner {
        lastTokenId = _id;
    }

    function getStatus() external view returns (uint256 _status) {
        if (block.timestamp <= incentivizingPeriod) {
            return 0;
        } else if (
            block.timestamp >= incentivizingPeriod &&
            block.timestamp <= votingPeriod
        ) {
            return 1;
        } else {
            return 2;
        }
    }

    function setNftAddress(address _nftAddress) external onlyOwner {
        nftContractAddress = _nftAddress;
    }

    function claim(uint256 _projectId) public nonReentrant {
        // require(status == govtStatus.claiming, "cant do it now");
        require(block.timestamp >= votingPeriod, "cant do it now");

        require(
            _projectId != getWinnerProjectId(),
            "cant claim winner project"
        );

        Briber[] storage tempx = bribers[msg.sender];
        for (uint256 i = 0; i < tempx.length; i++) {
            if (tempx[i].projectId != getWinnerProjectId()) {
                require(
                    IERC20(tempx[i].tokenAddress).transfer(
                        msg.sender,
                        tempx[i].tokenAmnt
                    ),
                    "transaction failed"
                );
                tempx[i].tokenAmnt = 0;
            }
        }

        NativeBriber[] storage tempy = nativeBribers[msg.sender];
        for (uint256 i = 0; i < tempy.length; i++) {
            if (tempy[i].projectId != getWinnerProjectId()) {
                (bool success, ) = payable(tempy[i].briberAddress).call{
                    value: tempy[i].tokenAmnt
                }("");
                require(success, "Transfer failed");
                tempy[i].tokenAmnt = 0;
            }
        }
    }

    function withdrawWinnerProject(
        address _receiver,
        uint _start,
        uint _end
    ) public nonReentrant onlyOwner {
        // require(status == govtStatus.claiming, "cant do it now");
        require(block.timestamp >= votingPeriod, "cant do it now");
        // require(_projectId == winnerProjectId, " claim winner project");
        uint256 winnerId = getWinnerProjectId();
        Project storage newProject = projects[winnerId];
        for (uint256 i = _start; i < _end; i++) {
            Briber[] storage tempx = bribers[newProject.bribers[i]];

            for (uint256 j = 0; j < tempx.length; j++) {
                if (tempx[j].projectId == getWinnerProjectId()) {
                    require(
                        IERC20(tempx[j].tokenAddress).transfer(
                            _receiver,
                            tempx[j].tokenAmnt
                        ),
                        "transaction failed"
                    );
                    tempx[j].tokenAmnt = 0;
                }
            }
            // delete newProject.bribers[i];
        }
        for (uint256 i = _start; i < _end; i++) {
            NativeBriber[] storage tempx = nativeBribers[
                newProject.nativeBribers[i]
            ];

            for (uint256 j = 0; j < tempx.length; j++) {
                if (tempx[j].projectId == getWinnerProjectId()) {
                    require(payable(_receiver).send(tempx[j].tokenAmnt));

                    tempx[j].tokenAmnt = 0;
                }
            }
            // delete newProject.nativeBribers[i];
        }
    }

    // function changeState(uint256 _stateNumber) public onlyOwner {
    //     if (_stateNumber == 0) {
    //         status = govtStatus.incentivising;
    //     }
    //     if (_stateNumber == 1) {
    //         status = govtStatus.voting;
    //     }
    //     if (_stateNumber == 2) {

    //         status = govtStatus.claiming;
    //     }
    // }

    function getWinnerProjectId() public view returns (uint256 _id) {
        uint256 _winnerProjectId = 1;
        for (uint256 i = 1; i <= projectCount; i++) {
            if (projects[i].votes > projects[_winnerProjectId].votes) {
                _winnerProjectId = i;
            }
        }
        return _winnerProjectId;
    }
}
