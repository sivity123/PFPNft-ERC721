// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GenerateInput is Script {
    uint256 count;
    string[] whitelist = new string[](4);
    string private constant INPUT_PATH = "/script/target/input.json";

    function run() public {
        whitelist[0] = "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"; // ac 1
        whitelist[1] = "0x70997970C51812dc3A010C7d01b50e0d17dc79C8"; // ac 2
        whitelist[2] = "0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC"; // ac 3
        whitelist[3] = "0x90F79bf6EB2c4f870365E785982E1f101E93b906"; // ac 6

        count = whitelist.length;

        string memory input = _createJSON();
        vm.writeFile(string.concat(vm.projectRoot(), INPUT_PATH), input);

        console.log("DONE: The output is found at %s", INPUT_PATH);
    }

    function _createJSON() internal view returns (string memory) {
        string memory countString = vm.toString(count);
        string memory json =
            string.concat('{ "types": ["address"], "count":', countString, ',"values": {');

        for (uint256 i = 0; i < whitelist.length; i++) {
            if (i == whitelist.length - 1) {
                json = string.concat(
                    json,
                    '"', vm.toString(i), '"',
                    ': { "0":"', whitelist[i], '" }'
                );
            } else {
                json = string.concat(
                    json,
                    '"', vm.toString(i), '"',
                    ': { "0":"', whitelist[i], '" },'
                );
            }
        }

        json = string.concat(json, "} }");
        return json;
    }
}