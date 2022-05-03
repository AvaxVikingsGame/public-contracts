// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

library SafeCastExtended {

    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "value doesn't fit in 248 bits");
        return uint248(value);
    }

    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "value doesn't fit in 240 bits");
        return uint240(value);
    }

    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "value doesn't fit in 232 bits");
        return uint232(value);
    }

    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "value doesn't fit in 224 bits");
        return uint224(value);
    }

    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "value doesn't fit in 216 bits");
        return uint216(value);
    }

    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "value doesn't fit in 208 bits");
        return uint208(value);
    }

    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "value doesn't fit in 200 bits");
        return uint200(value);
    }

    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "value doesn't fit in 192 bits");
        return uint192(value);
    }

    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "value doesn't fit in 184 bits");
        return uint184(value);
    }

    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "value doesn't fit in 176 bits");
        return uint176(value);
    }

    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "value doesn't fit in 168 bits");
        return uint168(value);
    }

    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "value doesn't fit in 160 bits");
        return uint160(value);
    }

    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "value doesn't fit in 152 bits");
        return uint152(value);
    }

    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "value doesn't fit in 144 bits");
        return uint144(value);
    }

    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "value doesn't fit in 136 bits");
        return uint136(value);
    }

    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "value doesn't fit in 128 bits");
        return uint128(value);
    }

    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "value doesn't fit in 120 bits");
        return uint120(value);
    }

    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "value doesn't fit in 112 bits");
        return uint112(value);
    }

    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "value doesn't fit in 104 bits");
        return uint104(value);
    }

    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "value doesn't fit in 96 bits");
        return uint96(value);
    }

    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "value doesn't fit in 88 bits");
        return uint88(value);
    }

    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "value doesn't fit in 80 bits");
        return uint80(value);
    }

    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "value doesn't fit in 72 bits");
        return uint72(value);
    }

    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "value doesn't fit in 64 bits");
        return uint64(value);
    }

    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "value doesn't fit in 56 bits");
        return uint56(value);
    }

    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "value doesn't fit in 48 bits");
        return uint48(value);
    }

    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "value doesn't fit in 40 bits");
        return uint40(value);
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "value doesn't fit in 32 bits");
        return uint32(value);
    }

    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "value doesn't fit in 24 bits");
        return uint16(value);
    }

    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "value doesn't fit in 16 bits");
        return uint16(value);
    }

    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "value doesn't fit in 8 bits");
        return uint8(value);
    }

}