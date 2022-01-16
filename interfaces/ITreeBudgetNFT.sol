// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
interface ITreeBudgetNFT {

    function mintMother(address account, int96 _flowRate,bytes memory data)
        external
        virtual 
        returns(uint256);
}