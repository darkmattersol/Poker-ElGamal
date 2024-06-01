// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import "./BitMaps.sol";

struct Deck {
    // x0 of cards
    uint256[] X0;
    // x1 of cards
    uint256[] X1;
    // Y0 of cards
    uint256[] Y0;
    // Y1 of cards
    uint256[] Y1;
    // 2 selectors for recovering y coordinates
    BitMaps.BitMap256 selector0;
    BitMaps.BitMap256 selector1;
}
