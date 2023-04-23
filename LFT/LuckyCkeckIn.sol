/***
* MIT License
* ===========
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
 __         __     ______   ______     ______   ______     ______     __    __    
/\ \       /\ \   /\  ___\ /\  ___\   /\  ___\ /\  __ \   /\  == \   /\ "-./  \   
\ \ \____  \ \ \  \ \  __\ \ \  __\   \ \  __\ \ \ \/\ \  \ \  __<   \ \ \-./\ \  
 \ \_____\  \ \_\  \ \_\    \ \_____\  \ \_\    \ \_____\  \ \_\ \_\  \ \_\ \ \_\ 
  \/_____/   \/_/   \/_/     \/_____/   \/_/     \/_____/   \/_/ /_/   \/_/  \/_/ 
                                                                                  
* The above copyright notice and this permission notice shall be included in all
* copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
*/

// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LuckyCheckIn is Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _sbtContracts;
    uint256 public _activityID;
    mapping(address => uint256) public _checkInDB;

    event eCheckIn(
        uint256 activityID,
        address owner,
        uint256 createdTime,
        uint256 blockNum
    );

    event eNewActivity(
        uint256 activityID,
        uint256 createdTime,
        uint256 blockNum
    );

    constructor(address defaulContract) {
        addSBTContract(defaulContract);
        newActivity();
    }

    //draw checkIn
    function checkIn() public {
        require(verify(), "An invalid identity!");
        _checkInDB[msg.sender] = _activityID;
        emit eCheckIn(_activityID, msg.sender, block.timestamp, block.number);
    }

    //new activity
    function newActivity() public onlyOwner {
        _activityID++;
        emit eNewActivity(_activityID, block.timestamp, block.number);
    }

    //add a sbt contract to white list
    function addSBTContract(address sbtContract) public onlyOwner {
        if (!_sbtContracts.contains(sbtContract)) {
            _sbtContracts.add(sbtContract);
        }
    }

    //remove a sbt contract from white list
    function removeSBTContract(address sbtContract) public onlyOwner {
        if (_sbtContracts.contains(sbtContract)) {
            _sbtContracts.remove(sbtContract);
        }
    }

    //get sbt contract in  white list
    function getSBTContracts() public view returns (address[] memory) {
        return _sbtContracts.values();
    }

    //get current activity ID
    function getActivityID() public view returns (uint256) {
        return _activityID;
    }

    //verify the draw permissions
    function verify() public view returns (bool) {
        if (_checkInDB[msg.sender] == _activityID) {
            return false;
        }
        //for sbtContract verify
        address sbtContract;
        for (uint256 i = 0; i < _sbtContracts.length(); i++) {
            sbtContract = _sbtContracts.at(i);
            if (sbtContract != address(0x0)) {
                if ((IERC721)(sbtContract).balanceOf(msg.sender) > 0) {
                    return true;
                }
            }
        }

        return false;
    }
}
