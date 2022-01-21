// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
interface ITreeBudgetNFT {

    function mintMother(
        address account,
        int96 _flowRate,
        bytes memory data
    )
        external 
        returns(uint256);//mints the mother token and returns the token Id

    function addTokenSource(
        uint id,
        address _source
    ) external; //adds the mother token flow source

    function mintChild(
        uint id,
        address newOwner,
        bytes memory data
    )
        external;

    function mintGChild(
        address newOwner,
        uint id,
        bytes memory data
    )
        external;
    
    function mintGreatGChild(
        address newOwner,
        uint token,
        uint amount
        //uint32 indexId,
        //int96 share
    ) external;

    function motherInfo(uint id) external returns(
        address tokenParent,
        address tokenOwner,
        int96 flowrate,
        bool forSale,
        uint256 price,
        uint lifeSpan
    );

    function tokenInfo(
        uint token_,
        uint id_
    ) external view returns(
        address tokenParent,
        address tokenOwner,
        int96 flowrate,
        bool conceived,
        bool forSale,
        uint256 price,
        uint lifeSpan
    );

    function gGchildInfo(uint id) external returns(
        address tokenParent,
        address tokenOwner,
        int96 amount,
        bool forSale,
        uint256 price,
        uint128 units
    );

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;
}