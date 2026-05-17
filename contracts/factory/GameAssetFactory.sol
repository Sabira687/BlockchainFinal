// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameItems} from "../tokens/GameItems.sol";

contract GameAssetFactory {
    error ZeroAddress();
    error EmptyUri();

    event CollectionDeployed(
        address indexed collection, address indexed owner, string baseUri, bytes32 indexed salt, bool deterministic
    );

    function deployCollectionCreate(address owner, string memory baseUri) external returns (address collection) {
        if (owner == address(0)) {
            revert ZeroAddress();
        }

        if (bytes(baseUri).length == 0) {
            revert EmptyUri();
        }

        collection = address(new GameItems(owner, baseUri));

        emit CollectionDeployed(collection, owner, baseUri, bytes32(0), false);
    }

    function deployCollectionCreate2(address owner, string memory baseUri, bytes32 salt)
        external
        returns (address collection)
    {
        if (owner == address(0)) {
            revert ZeroAddress();
        }

        if (bytes(baseUri).length == 0) {
            revert EmptyUri();
        }

        collection = address(new GameItems{salt: salt}(owner, baseUri));

        emit CollectionDeployed(collection, owner, baseUri, salt, true);
    }

    function predictCreate2Address(address owner, string memory baseUri, bytes32 salt)
        external
        view
        returns (address predicted)
    {
        bytes memory bytecode = abi.encodePacked(type(GameItems).creationCode, abi.encode(owner, baseUri));

        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), salt, keccak256(bytecode)));

        predicted = address(uint160(uint256(hash)));
    }
}
