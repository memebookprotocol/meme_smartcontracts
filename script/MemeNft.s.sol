// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "../src/MemePigeonNFT.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MemeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MemePigeonNFT nft = new MemePigeonNFT();

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(nft),
            new bytes(0x8129fc1c)
        );
        vm.stopBroadcast();
    }
}
