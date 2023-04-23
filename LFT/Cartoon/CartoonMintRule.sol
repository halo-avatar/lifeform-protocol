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
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../Interface/ICartoonMintRule.sol";
import "../Interface/ICartoon721.sol";

contract CartoonMintRule is ICartoonMintRule, Ownable, ReentrancyGuard  {

    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public _factory;
    address public _teamWallet;
    ICartoon721 public  _avatar721;

    struct BurnList{
        uint256 tokenId;
        uint256 freePoint;
    }
    //for burn list
    mapping(address  => EnumerableSet.UintSet) private _burnAssetList;
    //tokenid->free time point
    mapping(uint256 => uint256) public _freeTimePoint;
  
    //the max burn duration
    uint256 public _burnDuration = 7 days;  
    //the basic fast burn fee rate
    uint256 public _fastBurnFeeRate = 3000; //30%

    constructor(
        address factory,
        address avatar721, 
        address teamWallet

    ){

        require(factory != address(0x0), "invalid factory address!");
        require(avatar721 != address(0x0), "invalid avatar721 address!");
        require(teamWallet != address(0x0), "invalid teamWallet address!");

        _factory = factory ;
        _avatar721 = ICartoon721(avatar721);
        _teamWallet = teamWallet;
    }

    function updateTeamWallet(address teamWallet) public onlyOwner
    {
        require(teamWallet != address(0x0), "invalid teamWallet address!");
        _teamWallet = teamWallet;
    }

    function updateFactory(address factory) public onlyOwner
    {
        require(factory != address(0x0), "invalid factory address!");
        _factory = factory ;
    }

    function updateNftImpl(address avatar721) public onlyOwner
    {
        require(avatar721 != address(0x0), "invalid avatar721 address!");
        _avatar721 = ICartoon721(avatar721);
    }

    function updateBurnNumber(uint256 burnDuration, uint256 fastBurnFeeRate ) public onlyOwner {
        _burnDuration = burnDuration;
        _fastBurnFeeRate = fastBurnFeeRate;
    }

    function mint(         
        uint256 udIndex,
        address stakeErc20,
        uint256 stakeErc20Amount,
        address costErc20,
        uint256 costErc20Amount,
        uint256 mintType) external virtual override {
        
        require( _factory == msg.sender," invalid factory caller" );

        if(stakeErc20Amount>0){
            (IERC20)(stakeErc20).safeTransferFrom(tx.origin, address(this), stakeErc20Amount);
        }

        if(costErc20Amount>0){
             (IERC20)(costErc20).safeTransferFrom(tx.origin, _teamWallet, costErc20Amount);
        }

        uint256 id = _avatar721.mint(tx.origin, address(this), stakeErc20, stakeErc20Amount);
        
        emit Avatar721Mint(
                id,
                udIndex,
                mintType,
                address(this),
                tx.origin,
                address(_avatar721)
            );   
    }

    function applyBurnAvatar721( uint256 tokenId, bool force) public nonReentrant {
      
        IERC721 avatar = (IERC721)((address)(_avatar721));

        bool burning= _burnAssetList[msg.sender].contains(tokenId);

        require( burning || avatar.ownerOf(tokenId) == msg.sender, "invalid tokenId!");
        
        if( !burning ){

            avatar.safeTransferFrom(msg.sender, address(this), tokenId);
            _burnAssetList[msg.sender].add(tokenId);
            _freeTimePoint[tokenId] = block.timestamp;
            
        }

        if(force){
            _burnAvatar721(tokenId);
        }


    }

    function claimBurnHeritage() public nonReentrant {

        uint256 length = _burnAssetList[msg.sender].length();
        uint256[] memory ids = new uint256[](length);

        uint256 tokenId;
        uint256 count = 0;
        for(uint32 i=0; i<length; i++){
            tokenId = _burnAssetList[msg.sender].at(i);
            if(_freeTimePoint[tokenId].add(_burnDuration) < block.timestamp){
                ids[count] = tokenId;
                count = count.add(1);
            }
        }

        require(count>0, "empty burn asset list!");

        for(uint32 i=0; i<count; i++ ){
            _burnAvatar721(ids[i]);
        }
    }

    function getBurnList() public view returns( BurnList[] memory) {

        uint256 length = _burnAssetList[msg.sender].length();
        BurnList[] memory burnList = new BurnList[](length);

        uint256 tokenId;
        for(uint32 i=0; i<length; i++){
            tokenId = _burnAssetList[msg.sender].at(i);
            burnList[i].tokenId = tokenId;
            burnList[i].freePoint = _freeTimePoint[tokenId].add(_burnDuration);
        }

        return burnList;
    }

    function _burnAvatar721( uint256 tokenId) internal  {

        _avatar721.burn(tokenId);

        ICartoon721.ExtraInfo memory extraInfo = _avatar721.getExtraInfo(tokenId);
        if(extraInfo.stakeAmount>0){

            require(extraInfo.stakeErc20 != address(0x0), "invalid erc20 address" );

            //fast burn fee split
            uint256 returnAmount = extraInfo.stakeAmount;
            if(_burnAssetList[msg.sender].contains(tokenId) ){

                uint256 maxFee = extraInfo.stakeAmount.mul(_fastBurnFeeRate).div(10000);
                uint256 punishFee = 0;
                uint256 finalFreeTime = _freeTimePoint[tokenId].add(_burnDuration);
                if(block.timestamp<finalFreeTime){
                    punishFee = maxFee.mul(finalFreeTime.sub(block.timestamp)).div(_burnDuration);
                }

                _burnAssetList[msg.sender].remove(tokenId);
                _freeTimePoint[tokenId] = 0;

                if(punishFee>0){
                    (IERC20)(extraInfo.stakeErc20).safeTransfer(_teamWallet, punishFee);
                }
                returnAmount = extraInfo.stakeAmount.sub(punishFee);

            }
        
            (IERC20)(extraInfo.stakeErc20).safeTransfer(msg.sender, returnAmount);
        }
        else{
             if(_burnAssetList[msg.sender].contains(tokenId) ){
                _burnAssetList[msg.sender].remove(tokenId);
                _freeTimePoint[tokenId] = 0;
             }
        }

        emit Avatar721Burn(
                extraInfo.id,
                extraInfo.stakeErc20,
                extraInfo.stakeAmount,
                tx.origin,
                address(_avatar721)
            );
            
    }

    function withdrawBNB(address target) public  onlyOwner {
        payable(target).transfer(address(this).balance);
    }

    function urgencyWithdrawErc20(address erc20, address target) public  onlyOwner {
        IERC20(erc20).safeTransfer(target, IERC20(erc20).balanceOf(address(this)));
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFT721Received(operator, from, tokenId, data);
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }

}