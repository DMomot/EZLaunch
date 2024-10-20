pragma solidity ^0.8.28;

library UnsafeMath {
    function unsafeDiv(uint256 x, uint256 y) internal pure returns (uint256 z) {
        unchecked {
            z = x / y;
        }
    }
}