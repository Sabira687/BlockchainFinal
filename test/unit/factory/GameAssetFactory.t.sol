// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameAssetFactory} from "../../../contracts/factory/GameAssetFactory.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";

contract GameAssetFactoryTest is Test {
    GameAssetFactory private factory;

    address private owner = address(0xA11CE);
    string private baseUri = "ipfs://factory-items/";

    function setUp() public {
        factory = new GameAssetFactory();
    }

    function testDeployCollectionWithCreate() public {
        address collection = factory.deployCollectionCreate(owner, baseUri);
        GameItems items = GameItems(collection);

        assertEq(items.owner(), owner);
        assertEq(items.uri(items.WOOD()), "ipfs://factory-items/1.json");
    }

    function testDeployCollectionWithCreate2() public {
        bytes32 salt = keccak256("GAME_COLLECTION");
        address predicted = factory.predictCreate2Address(owner, baseUri, salt);

        address collection = factory.deployCollectionCreate2(owner, baseUri, salt);

        assertEq(collection, predicted);
        assertEq(GameItems(collection).owner(), owner);
    }

    function testCannotDeployWithZeroOwner() public {
        vm.expectRevert(GameAssetFactory.ZeroAddress.selector);
        factory.deployCollectionCreate(address(0), baseUri);

        vm.expectRevert(GameAssetFactory.ZeroAddress.selector);
        factory.deployCollectionCreate2(address(0), baseUri, keccak256("SALT"));
    }

    function testCannotDeployWithEmptyUri() public {
        vm.expectRevert(GameAssetFactory.EmptyUri.selector);
        factory.deployCollectionCreate(owner, "");

        vm.expectRevert(GameAssetFactory.EmptyUri.selector);
        factory.deployCollectionCreate2(owner, "", keccak256("SALT"));
    }
}
