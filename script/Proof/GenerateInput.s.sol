// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract GenerateInput is Script {
    uint256 count;
    string[] whitelist = new string[](4);
    string private constant INPUT_PATH = "/script/targetSepolia/sepoliaInput.json";

    function run() public {
        whitelist[0] = "0x002a5e5E33990194FB51E6dE9a86b6aabb293cBB"; // ac 1
        whitelist[1] = "0xE5d2F8696E9EBEf7781c25E70e963fAd03870279"; // ac 2
        whitelist[2] = "0x301Ed835fC64660F20a141907270a694124d1063"; // ac 3
        whitelist[3] = "0x15b6B8a1643eABAAC039c4C4eF634e598176cdc5"; // ac 6

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