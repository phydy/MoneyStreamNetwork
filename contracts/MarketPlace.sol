// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "../ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {ITreeBudgetNFT} from "../interfaces/ITreeBudgetNFT.sol";
import {
    ISuperToken
} from "../supercon/interfaces/superfluid/ISuperToken.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";



contract MarketPlace is ReentrancyGuard {
    ITreeBudgetNFT treeNFT;
    ISuperToken DAI;

    struct Derivative {
        uint price;
        int96 flowRate;
        uint duration;
        address seller;
    }

    mapping(uint => mapping (uint => Derivative)) public tokenIdInfo;

    //mapping(uint => mapping(uint => uint)) tokenIdPrice;
    //mapping(uint => mapping(uint => int96)) tokenIdFlowRate;
    //mapping(uint => mapping(uint => uint)) tokenIdDuration;
    //mapping(uint => mapping(uint => address)) tokenIdSeller;



    constructor
    (
        ITreeBudgetNFT _treeAddress,
        ISuperToken dai
    ) 
    {
        treeNFT = _treeAddress;
        DAI = dai;
    }

    function toUint(int96 _number) public pure returns(uint256) {
        int256 number = _number;
        return(uint256(number));
    }
    
    function getTokenDetails(uint token, uint id) public view returns(address, int96, uint) {

    }
    function addTokenDetails(
        uint token,
        uint id,
        uint price,
        int96 flowRate_,
        uint duration,
        address seller
    ) external nonReentrant
    {

        tokenIdInfo[token][id] = Derivative(
            price,
            flowRate_,
            duration,
            seller
        );
    }

    function mintToken(uint token, uint id) public {
        require(token > 0 && token < 3, "wrong token");
        //require(DAI.allowance(address(this), msg.sender)>=  tokenIdInfo[token][id].price);
        //DAI.transferFrom(msg.sender, tokenIdInfo[token][id].seller, tokenIdInfo[token][id].price);
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

    function mintGreat(uint id, uint amount) public {
        treeNFT.mintGreatGChild(
            msg.sender,
            id,
            amount
        );
    }

    function buyToken(uint token, uint id) public {
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