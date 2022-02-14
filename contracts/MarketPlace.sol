// SPDX-License-Identifier: MIT

contract Factory {

    event Deployed(address addr, uint salt);

    // 1. Get bytecode of contract to be deployed
    // NOTE: _owner and _foo are arguments of the TestContract's constructor
    function getBytecode(address _owner, uint _foo) public pure returns (bytes memory) {
        bytes memory bytecode = type(MarketPlace).creationCode;

        return abi.encodePacked(bytecode, abi.encode(_owner, _foo));
    }

    // 2. Compute the address of the contract to be deployed
    // NOTE: _salt is a random number used to create an address
    function getAddress(bytes memory bytecode, uint _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint(hash)));
    }

    // 3. Deploy the contract
    // NOTE:
    // Check the event log Deployed which contains the address of the deployed TestContract.
    // The address in the log should equal the address computed from above.
    function deploy(bytes memory bytecode, uint _salt) public payable {
        address addr;

        /*
        NOTE: How to call create2

        create2(v, p, n, s)
        create new contract with code at memory p to p + n
        and send v wei
        and return the new address
        where new address = first 20 bytes of keccak256(0xff + address(this) + s + keccak256(mem[p…(p+n)))
              s = big-endian 256-bit value
        */
        assembly {
            addr := create2(
                callvalue(), // wei sent with current call
                // Actual code starts after skipping the first 32 bytes
                add(bytecode, 0x20),
                mload(bytecode), // Load the size of code contained in the first 32 bytes
                _salt // Salt from function arguments
            )

            if iszero(extcodesize(addr)) {
                revert(0, 0)
            }
        }

        emit Deployed(addr, _salt);
    }
}


pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITreeBudgetNFT} from "../interfaces/ITreeBudgetNFT.sol";
import {
    ISuperToken
} from "@superfluid/interfaces/superfluid/ISuperToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



contract MarketPlace is ReentrancyGuard {
    ITreeBudgetNFT treeNFT;
    ISuperToken public DAI;

    struct Derivative {
        uint price;
        int96 flowRate;
        uint duration;
        address seller;
        bool active;
    }

    struct IndexInfo {
        uint duration;
        uint startTime;
        uint actualAmount;
        uint remainingAmount;
    }

    mapping(uint => mapping (uint => Derivative)) public tokenIdInfo;
    mapping(uint32 => IndexInfo) public indexInformation;

    event tokenAdded(address indexed from, uint256 indexed token, uint indexed id, int96 flowRate);
    constructor
    (
        ITreeBudgetNFT _treeAddress,
        ISuperToken dai,
        IERC20 fdai
    ) 
    {
        treeNFT = _treeAddress;
        DAI = dai;
    }

    function toUint(int96 _number) public pure returns(uint256) {
        int256 number = _number;
        return(uint256(number));
    }
    
    function getTokenDetails(
        uint token,
        uint id
    ) public view returns(
        uint,
        int96,
        uint,
        address
    ) {
        uint price = tokenIdInfo[token][id].price;
        int96 flowRate = tokenIdInfo[token][id].flowRate;
        uint duration = tokenIdInfo[token][id].duration;
        address seller = tokenIdInfo[token][id].seller;
        return (price, flowRate, duration, seller);
    }
    function addTokenDetails(
        uint token,
        uint id,
        uint price,
        int96 flowRate_,
        uint duration,
        address seller,
        bool _active
    ) external nonReentrant
    {
        tokenIdInfo[token][id] = Derivative(
            price,
            flowRate_,
            duration,
            seller,
            _active
        );
        emit tokenAdded(seller, token, id, flowRate_);
    }

    function addIndex(
        uint32 index,
        uint256 duration,
        uint256 actualAmount
    ) external nonReentrant {
        indexInformation[index] = IndexInfo(
            duration,
            actualAmount,
            actualAmount,
            block.timestamp
        );
    }

    function mintToken(uint token, uint id) public nonReentrant {
        require(token > 0 && token < 3, "wrong token");
        require(tokenIdInfo[token][id].active == false);
        require(DAI.allowance(address(this), msg.sender)>=  tokenIdInfo[token][id].price, "allowance not enough");
        uint price = tokenIdInfo[token][id].price;
        address seller = tokenIdInfo[token][id].seller;
        DAI.transferFrom(
            msg.sender,
            seller,
            price
        );
        bytes memory data = "";
        if (token == 1) {
            treeNFT.mintChild(
                id,
                msg.sender,
                data
            );
        }
        else if (token == 2) {
            treeNFT.mintGChild(
                msg.sender,
                id,
                data
            );
        }
    }
/*
    function mintGreat(uint id, uint amount) public nonReentrant{
        treeNFT.mintGreatGChild(
            msg.sender,
            id,
            amount
        );
    }
*/
    function buyToken(
        uint token,
        uint id
    ) public nonReentrant {
        require(tokenIdInfo[token][id].active == true);
        bytes memory data = "";
        address from = tokenIdInfo[token][id].seller;
        uint price = tokenIdInfo[token][id].price;
        DAI.transferFrom(
            msg.sender,
            from,
            price
        );
        treeNFT.safeTransferFrom(
            from,
            msg.sender,
            token,
            1,
            data
        );
    } 
}
