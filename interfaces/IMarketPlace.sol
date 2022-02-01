// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IMarketPlace {

    function addTokenDetails(
        uint token,
        uint id,
        uint price,
        int96 flowRate_,
        uint duration,
        address seller,
        bool _active
    ) external;

    function addIndex(
        uint32 index,
        uint256 duration,
        uint256 actualAmount
    ) external;
}