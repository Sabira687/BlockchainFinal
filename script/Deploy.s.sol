// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {GameToken} from "../contracts/tokens/GameToken.sol";
import {GameItems} from "../contracts/tokens/GameItems.sol";
import {ResourceAMM} from "../contracts/core/ResourceAMM.sol";
import {CraftingSystem} from "../contracts/core/CraftingSystem.sol";
import {LootBox} from "../contracts/core/LootBox.sol";
import {GameYieldVault} from "../contracts/vault/GameYieldVault.sol";
import {ItemRentalVault} from "../contracts/vault/ItemRentalVault.sol";
import {GameGovernor} from "../contracts/governance/GameGovernor.sol";
import {MockRandomnessProvider} from "../contracts/oracle/MockRandomnessProvider.sol";
import {MockV3Aggregator} from "../contracts/oracle/MockV3Aggregator.sol";
import {GamePriceOracle} from "../contracts/oracle/GamePriceOracle.sol";
import {GameAssetFactory} from "../contracts/factory/GameAssetFactory.sol";
import {GameConfigV1} from "../contracts/upgrade/GameConfigV1.sol";

contract Deploy is Script {
    bytes32 private constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 private constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        GameToken gameToken = new GameToken(deployer);
        GameToken resourceToken = new GameToken(deployer);
        GameItems gameItems = new GameItems(deployer, "ipfs://gamefi-items/");

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);

        TimelockController timelock = new TimelockController(2 days, proposers, executors, deployer);
        GameGovernor governor = new GameGovernor(gameToken, timelock);

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.grantRole(CANCELLER_ROLE, address(governor));

        ResourceAMM amm = new ResourceAMM(deployer, address(gameToken), address(resourceToken));
        GameYieldVault yieldVault = new GameYieldVault(deployer, gameToken);
        ItemRentalVault rentalVault = new ItemRentalVault(deployer, gameItems, gameToken);
        CraftingSystem craftingSystem = new CraftingSystem(address(timelock), gameItems);

        MockRandomnessProvider randomnessProvider = new MockRandomnessProvider();
        LootBox lootBox =
            new LootBox(address(timelock), gameItems, address(randomnessProvider), gameItems.LEGENDARY_RELIC());

        MockV3Aggregator priceFeed = new MockV3Aggregator(8, 2_000e8);
        GamePriceOracle priceOracle = new GamePriceOracle(address(priceFeed), 1 hours);

        GameAssetFactory assetFactory = new GameAssetFactory();

        GameConfigV1 configImplementation = new GameConfigV1();
        bytes memory configInitData =
            abi.encodeCall(GameConfigV1.initialize, (address(timelock), deployer, 0.01 ether, 0.05 ether));
        ERC1967Proxy configProxy = new ERC1967Proxy(address(configImplementation), configInitData);

        gameItems.transferOwnership(address(timelock));
        timelock.revokeRole(DEFAULT_ADMIN_ROLE, deployer);

        vm.stopBroadcast();

        console2.log("Deployer:", deployer);
        console2.log("GameToken:", address(gameToken));
        console2.log("ResourceToken:", address(resourceToken));
        console2.log("GameItems:", address(gameItems));
        console2.log("Timelock:", address(timelock));
        console2.log("Governor:", address(governor));
        console2.log("ResourceAMM:", address(amm));
        console2.log("GameYieldVault:", address(yieldVault));
        console2.log("ItemRentalVault:", address(rentalVault));
        console2.log("CraftingSystem:", address(craftingSystem));
        console2.log("RandomnessProvider:", address(randomnessProvider));
        console2.log("LootBox:", address(lootBox));
        console2.log("PriceFeed:", address(priceFeed));
        console2.log("PriceOracle:", address(priceOracle));
        console2.log("GameAssetFactory:", address(assetFactory));
        console2.log("GameConfigImplementation:", address(configImplementation));
        console2.log("GameConfigProxy:", address(configProxy));
    }
}
