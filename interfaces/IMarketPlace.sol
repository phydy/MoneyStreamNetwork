// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface IMarketPlace {

    function addTokenDetails(
        uint token,
        uint id,
        uint price,
        int96 flowRate_,
        uint duration,
        address seller
    ) external;
}