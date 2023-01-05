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
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../Interface/IAvatarMintRule.sol";

contract BaseMintRule is IAvatarMintRule, Ownable, ReentrancyGuard  {

    using EnumerableSet for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public _factory;
    address public _teamWallet;
    IAvatar721 public  _avatar721;

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
        _factory = factory ;
        _avatar721 = IAvatar721(avatar721);
        _teamWallet = teamWallet;
    }

    function updateFactory(address factory) public onlyOwner
    {
        _factory = factory ;
    }

    function updateNftImpl(address avatar721) public onlyOwner
    {
        _avatar721 = IAvatar721(avatar721);
    }

    function updateBurnNumber(uint256 burnDuration, uint256 fastBurnFeeRate ) public onlyOwner {
        _burnDuration = burnDuration;
        _fastBurnFeeRate = fastBurnFeeRate;
    }

    function mint( MintRule calldata mintData ) external virtual override {
        
        require( _factory == msg.sender," invalid factory caller" );

        require( mintData.costErc20Amount>0 || mintData.children721.length>0,"invalid mintCodition" );
        
        if(mintData.stakeErc20Amount>0 && mintData.stakeErc20 != address(0x0)){
            (IERC20)(mintData.stakeErc20).safeTransferFrom(tx.origin, address(this), mintData.stakeErc20Amount);
        }

        if(mintData.costErc20Amount>0 && mintData.costErc20 != address(0x0)){
             (IERC20)(mintData.costErc20).safeTransferFrom(tx.origin, _teamWallet, mintData.costErc20Amount);
        }

        if(mintData.amount1155.length>0 && mintData.erc1155 != address(0x0)){
            (IERC1155)(mintData.erc1155).safeBatchTransferFrom(tx.origin, address(this), mintData.children1155, mintData.amount1155, "");
        }

        if(mintData.children721.length>0 && mintData.erc721 != address(0x0)){
            for (uint256 i = 0; i < mintData.children721.length; ++i) {
                (IERC721)(mintData.erc721).safeTransferFrom(tx.origin, address(this), mintData.children721[i],"");
            }
        }

        IAvatar721.ExtraInfo memory extraInfo;
        extraInfo.mintRule = address(this);
        extraInfo.erc20 = mintData.stakeErc20;
        extraInfo.erc20Amount = mintData.stakeErc20Amount;
        extraInfo.erc721 =  mintData.erc721;
        extraInfo.children721 =mintData.children721;
        extraInfo.erc1155 =  mintData.erc1155;
        extraInfo.children1155 = mintData.children1155;
        extraInfo.amount1155 = mintData.amount1155;
        extraInfo.id = 0;

        uint256 id = _avatar721.mint(tx.origin, extraInfo);
        emit Avatar721Mint(
                id,
                mintData.udIndex,
                mintData.costErc20Amount,
                mintData.stakeErc20Amount,
                mintData.children721,
                mintData.children1155,
                mintData.amount1155,
                mintData.mintRule,
                tx.origin,
                address(_avatar721)
            );  
    }

    function applyBurnAvatar721( uint256 tokenId, bool force) public nonReentrant {
      
        IERC721 avatar = (IERC721)((address)(_avatar721));
        require( avatar.ownerOf(tokenId) == msg.sender, "invalid tokenId!");
        
        if( !_burnAssetList[msg.sender].contains(tokenId) ){
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

        IAvatar721.ExtraInfo memory extraInfo = _avatar721.getExtraInfo(tokenId);
        if(extraInfo.erc20Amount>0){

            require(extraInfo.erc20 != address(0x0), "invalid erc20 address" );

            //fast burn fee split
            uint256 returnAmount = extraInfo.erc20Amount;
            if(_burnAssetList[msg.sender].contains(tokenId) ){

                uint256 maxFee = extraInfo.erc20Amount.mul(_fastBurnFeeRate).div(10000);
                uint256 punishFee = 0;
                uint256 finalFreeTime = _freeTimePoint[tokenId].add(_burnDuration);
                if(block.timestamp<finalFreeTime){
                    punishFee = maxFee.mul(finalFreeTime.sub(block.timestamp)).div(_burnDuration);
                }
                
                _burnAssetList[msg.sender].remove(tokenId);
                _freeTimePoint[tokenId] = 0;

                if(punishFee>0){
                    (IERC20)(extraInfo.erc20).safeTransfer(_teamWallet, punishFee);
                }
                returnAmount = extraInfo.erc20Amount.sub(punishFee);
            }
        
            (IERC20)(extraInfo.erc20).safeTransfer(msg.sender, returnAmount);
        }

        if(extraInfo.children721.length>0){
            require(extraInfo.erc721 != address(0x0), "invalid erc721 address" );
            for(uint256 i=0; i<extraInfo.children721.length; i++){
                (IERC721)(extraInfo.erc721).safeTransferFrom(address(this), msg.sender, extraInfo.children721[i]);
            }
        }

        if(extraInfo.amount1155.length>0){
            require(extraInfo.erc1155 != address(0x0), "invalid erc1155 address" );
            (IERC1155)(extraInfo.erc1155).safeBatchTransferFrom(address(this), msg.sender, extraInfo.children1155 , extraInfo.amount1155, "");
        }

        emit Avatar721Burn(
                extraInfo.id,
                extraInfo.erc20,
                extraInfo.erc20Amount,
                extraInfo.erc721,
                extraInfo.children721,
                extraInfo.erc1155,
                extraInfo.children1155,
                extraInfo.amount1155,
                tx.origin,
                address(_avatar721)
            );
            
    }

    function withdrawETH(address target) public  onlyOwner {
        payable(target).transfer(address(this).balance);
    }

    function urgencyWithdrawErc20(address erc20, address target) public  onlyOwner {
        IERC20(erc20).safeTransfer(target, IERC20(erc20).balanceOf(address(this)));
    }

    function urgencyWithdrawErc721(address erc721, address target, uint256[] calldata ids) external onlyOwner {
        for (uint256 i = 0; i < ids.length; ++i) {
            (IERC721)(erc721).safeTransferFrom(address(this), target, ids[i],"");
        }
    }

    function urgencyWithdrawErc1155(address erc1155, address target, uint256[] calldata ids,  uint256[] calldata amounts) public onlyOwner {
        IERC1155(erc1155).safeBatchTransferFrom(address(this), target, ids,amounts,"");
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

    function onERC1155Received(address operator, address from, uint256 tokenId, uint256 amount, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFT1155Received(operator, from, tokenId, amount, data);
        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function onERC1155BatchReceived(address operator, address from, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) public returns (bytes4) {
        //only receive the _nft staff
        if(address(this) != operator) {
            //invalid from nft
            return 0;
        }
        //success
        emit NFT1155BatchReceived(operator, from, tokenIds, amounts, data);
        return bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));
    }
}