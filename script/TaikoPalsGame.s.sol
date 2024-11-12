// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import "../src/TaikoPalsGame.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployTaikoPals is Script {
    TaikoPalsGame public implementation;
    ERC1967Proxy public proxy;
    TaikoPalsGame public game;

    function setUp() public {}

    function run() public {
        // Retrieve deployer private key and address
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployerAddress = vm.addr(deployerPrivateKey);
        
        console.log("Deploying TaikoPals with address:", deployerAddress);
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy implementation contract
        implementation = new TaikoPalsGame();
        console.log("Implementation deployed at:", address(implementation));

        // Encode the initialization call
        bytes memory initData = abi.encodeWithSelector(
            TaikoPalsGame.initialize.selector
        );

        // Deploy proxy contract
        proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        console.log("Proxy deployed at:", address(proxy));

        // Create a reference to the proxied contract
        game = TaikoPalsGame(address(proxy));
        
        // Verify initialization
        require(game.hasRole(game.ADMIN_ROLE(), deployerAddress), "Initialization failed: Deployer is not admin");
        require(game.hasRole(game.MINTER_ROLE(), deployerAddress), "Initialization failed: Deployer is not minter");
        require(game.hasRole(game.TRADER_ROLE(), deployerAddress), "Initialization failed: Deployer is not trader");

        console.log("Contract deployed and initialized successfully");
        console.log("Admin role granted to:", deployerAddress);

        vm.stopBroadcast();
    }
}