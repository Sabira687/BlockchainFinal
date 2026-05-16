// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract GameItems is Ownable, ERC1155, ERC1155Supply {
    uint256 public constant WOOD = 1;
    uint256 public constant STONE = 2;
    uint256 public constant IRON = 3;
    uint256 public constant CRYSTAL = 4;
    uint256 public constant SWORD = 100;
    uint256 public constant SHIELD = 101;
    uint256 public constant LEGENDARY_RELIC = 1000;

    error ZeroAddress();
    error InvalidAmount();

    constructor(address initialOwner, string memory baseUri) Ownable(initialOwner) ERC1155(baseUri) {
        if (initialOwner == address(0)) {
            revert ZeroAddress();
        }
    }

    function mint(address to, uint256 id, uint256 amount, bytes memory data) external onlyOwner {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        _mint(to, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        external
        onlyOwner
    {
        if (to == address(0)) {
            revert ZeroAddress();
        }

        _mintBatch(to, ids, amounts, data);
    }

    function burn(address from, uint256 id, uint256 amount) external {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }

        _burn(from, id, amount);
    }

    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external {
        if (from != msg.sender && !isApprovedForAll(from, msg.sender)) {
            revert ERC1155MissingApprovalForAll(msg.sender, from);
        }

        _burnBatch(from, ids, amounts);
    }

    function uri(uint256 id) public view override returns (string memory) {
        return string(abi.encodePacked(super.uri(id), _toString(id), ".json"));
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function _toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }

        return string(buffer);
    }
}
