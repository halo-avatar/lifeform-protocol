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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security//ReentrancyGuard.sol";

import "./Interface/IAdorn1155.sol";
import "./Interface/IAvatar721.sol";

contract AnswerFirst is ReentrancyGuard, Pausable, Ownable {

   enum RegisterType {
        eCash,
        eAvatar
    }

    event eNewActivity(
        uint256 activityId,
        uint256 startTime,
        uint256 endTime
    );

    event eRegister(
        uint256 tokenId, 
        address owner, 
        RegisterType registerType, 
        uint256 timestamp,
        uint256 activityId,
        string affCode
    );

    event eWithdraw( 
       uint256[] ids, 
       address owner, 
       uint256 timestamp, 
       uint256 activityId 
    );

    struct RegisterInfo{
        uint256 tokenId;
        uint256 startTime;
        uint256 activityId;
        string affCode;
        RegisterType registerType;
    }

    struct ActivityInfo{
        uint256 registerCount;
        uint256 allPay;
        uint256 endTime;
        uint256 startTime;
    }

    using SafeERC20 for IERC20;

    IAdorn1155 public _erc1155;
    IAvatar721 public _erc721;
    IERC20 public _erc20;
    uint256 public _registerFee = 20 ether;
    uint256 public _stakeFee = 1 ether;
    uint256 public _deltaTime = 24 hours - 10 minutes;
    address public _VAULT;

    uint256 public _airDropId;
    uint256 public _activityId;

    // for IAMs
    mapping(address => bool) public _IAMs;

    // for players
    mapping(uint256 => mapping( address => RegisterInfo )) public _registerInfo; // activityId=>address=>RegisterInfo
    // for activity info
    mapping(uint256 => ActivityInfo) public _activityInfo;

    modifier onlyIAM() {
        require(_IAMs[msg.sender], "must call by IAM");
        _;
    }

    constructor(address erc20, address erc721, address erc1155, uint256 airDropId, address VAULT ) {
        _erc20 = IERC20(erc20);
        _erc721 = IAvatar721(erc721);
        _erc1155 = IAdorn1155(erc1155);
        _airDropId = airDropId;
        _VAULT = VAULT;

        addIAM(msg.sender);
        newActivity(airDropId);
    }

    function setErc1155(address erc1155) public onlyOwner{
        _erc1155 = IAdorn1155(erc1155);
    }

    function setErc721(address erc721) public onlyOwner{
        _erc721 = IAvatar721(erc721);
    }

    function setErc20(address erc20) public onlyOwner{
        _erc20 = IERC20(erc20);
    }
    
    function setFee(uint256 registerFee,uint256 stakeFee) public onlyOwner{
        _registerFee = registerFee;
        _stakeFee = stakeFee;
    }

    function setActivityTime(uint256 startTime, uint256 deltaTime) public onlyOwner{
        _deltaTime = deltaTime;

        _activityInfo[_activityId].startTime = startTime;
        _activityInfo[_activityId].endTime = startTime+deltaTime;
    }

    function set1155Id(uint256 airDropId) public onlyOwner{
        _airDropId = airDropId;
    }

    function setVault(address VAULT) public onlyOwner{
        _VAULT = VAULT;
    }


    function addIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = true;
    }

    function removeIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = false;
    }
    
    function onERC721Received(address /*operator*/ , address /*from*/ , uint256 /*tokenId*/, bytes calldata  /*data*/) external pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function newActivity(uint256 airDropId) public onlyIAM {
        _activityId++;
        _activityInfo[_activityId].startTime = block.timestamp;
        _activityInfo[_activityId].endTime = block.timestamp + _deltaTime;
        
        _airDropId = airDropId;

        emit eNewActivity(_activityId,block.timestamp,block.timestamp + _deltaTime);
    }

    function isRegister(uint256 activityId, address owner ) public view returns(bool){
        return _registerInfo[activityId][owner].startTime != 0;
    }

    function getRegisterInfo(uint256 activityId,address owner) public view returns(RegisterInfo memory ){
        return  _registerInfo[activityId][owner];
    }

    function getActivityInfo(uint256 activityId) public view returns(ActivityInfo memory ){
        return  _activityInfo[activityId];
    }

    function getAllRegisterInfo(address owner) public view returns(RegisterInfo[] memory ){

        RegisterInfo[] memory records = new RegisterInfo[](_activityId+1);
        for(uint256 i=0; i<=_activityId; i++){
           records[i] = _registerInfo[i][owner];
        }
        return records;
    }

    function register(RegisterType registerType, uint256 tokenId, string calldata affCode) public whenNotPaused nonReentrant {
        require( !isRegister(_activityId,msg.sender), "already registered!");
        require( block.timestamp < _activityInfo[_activityId].endTime, "register time is up!");

        _activityInfo[_activityId].registerCount += 1;
       
        if(registerType == RegisterType.eAvatar){

            require( IERC721(address(_erc721)).ownerOf(tokenId) == msg.sender, "invalid owner!");
            IERC721(address(_erc721)).safeTransferFrom(msg.sender, address(this), tokenId);
            _registerInfo[_activityId][msg.sender].tokenId = tokenId;

            _erc20.safeTransferFrom(msg.sender, _VAULT, _stakeFee);
            _activityInfo[_activityId].allPay += _stakeFee;

        }
        else if(registerType == RegisterType.eCash){
            _erc20.safeTransferFrom(msg.sender, _VAULT, _registerFee);
            _activityInfo[_activityId].allPay += _registerFee;
        }
        else{
            require(false, "invalid register type!");
        }

        _registerInfo[_activityId][msg.sender].activityId=_activityId;
        _registerInfo[_activityId][msg.sender].startTime=block.timestamp;
        _registerInfo[_activityId][msg.sender].registerType=registerType;
        _registerInfo[_activityId][msg.sender].affCode=affCode;

        if(_airDropId>0){
            _erc1155.mint(msg.sender, _airDropId, 1, "");
        }

        emit eRegister(tokenId, msg.sender, registerType, block.timestamp, _activityId, affCode);
    }

    function withdrawNFTs() public whenNotPaused nonReentrant {

        uint256[] memory ids = new uint256[](_activityId);
        uint32 count=0;
        for(uint256 k=0; k<_activityId; k++){
            uint256 tokenId = _registerInfo[k][msg.sender].tokenId;
            if(tokenId > 0){
                IERC721(address(_erc721)).safeTransferFrom(address(this), msg.sender, tokenId);
                _registerInfo[k][msg.sender].tokenId=0;

                ids[count]=tokenId;
                count = count+1;
            }
        }

        require(count>0, "nothing to be withdrawed! the pledge hasn't expired yet");

        emit eWithdraw(ids, msg.sender, block.timestamp, _activityId);
       
    }

    function reward(address[] calldata whiteList,uint256[] calldata amounts) onlyIAM external  {

        require(whiteList.length == amounts.length, "count not match!");

        uint256 cost = 0;
        for(uint256 i=0; i<amounts.length; i++){
            cost = cost + amounts[i];
        }

        require(_erc20.balanceOf(address(this)) >= cost, "invalid cost amount! ");
        for (uint256 i=0; i<whiteList.length; i++) {
            require(whiteList[i] != address(0),"Address is not valid");
            _erc20.safeTransfer(whiteList[i], amounts[i]);
        }
        
    }

    function urgencyWithdrawErc721(address erc721, address target, uint256[] calldata ids) external onlyOwner {
        for (uint256 i = 0; i < ids.length; ++i) {
            (IERC721)(erc721).safeTransferFrom(address(this), target, ids[i],"");
        }
    }

    function pause() public onlyOwner{
        if(!paused()){
            _pause();
        }
        else{
            _unpause();
        }
    }

}
