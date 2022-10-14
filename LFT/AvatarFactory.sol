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
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./Interface/IAdorn721.sol";
import "./Interface/IAdorn1155.sol";
import "./Interface/IAvatar721.sol";

contract AvatarFactory is Ownable, ReentrancyGuard {

    event NFT721Received(address operator, address from, uint256 tokenId, bytes data);
    event NFT1155Received(address operator, address from, uint256 tokenId, uint256 amount, bytes data);
    event NFT1155BatchReceived(address operator, address from, uint256[] tokenIds, uint256[] amounts, bytes data);

    event Avatar721Mint(
        uint256 id,
        uint256 udIndex,
        // uint256 blockNum,
        address erc20,
        uint256 erc20Amount,
        address erc721,
        uint256[] children721,
        address erc1155,
        uint256[] children1155,
        uint256[] amount1155,
        address nftContract,
        address author
    );

    event Avatar721Burn(
        uint256 id,
        // uint256 blockNum,
        address erc20,
        uint256 erc20Amount,
        address erc721,
        uint256[] children721,
        address erc1155,
        uint256[] children1155,
        uint256[] amount1155,
        address who,
        address nftContract
        
    );

    using SafeERC20 for IERC20;
    using Address for address;

    // for IAMs
    mapping(address => bool) public _IAMs;

    bool public _isUserStart = false;

    IAdorn721 public  _adorn721;
    IAdorn1155 public  _adorn1155;
    IAvatar721 public  _avatar721;
    IERC20 public   _gvToken;

    constructor(
         address adorn721, 
         address adorn1155, 
         address avatar721 ,
         address gvToken

    ) {
        _adorn721 = IAdorn721(adorn721);
        _adorn1155 = IAdorn1155(adorn1155);
        _avatar721 = IAvatar721(avatar721);
        _gvToken = IERC20(gvToken);

        addIAM(msg.sender);
    }

    function updateNftImpl(address adorn721,address adorn1155,address avatar721) public onlyOwner
    {
        _adorn721 = IAdorn721(adorn721);
        _adorn1155 = IAdorn1155(adorn1155);
        _avatar721 = IAvatar721(avatar721);
    }

    function updateTokenImpl(address gvToken) public onlyOwner
    {
        _gvToken = IERC20(gvToken);
    }


    function setUserStart(bool start) public onlyOwner {
        _isUserStart = start;
    }

    function addIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = true;
    }

    function removeIAM(address IAM) public onlyOwner {
        _IAMs[IAM] = false;
    }


    function mintAvatar721(uint256 udIndex,IAvatar721.ExtraInfo calldata extraInfo) external nonReentrant
    {
        address origin = msg.sender;
        if(_IAMs[msg.sender] == false){
            require(!origin.isContract(), "lifeform: call to non-contract");
        }

        require( _isUserStart || _IAMs[msg.sender]  , "lifeform: can't mint" );

        require(extraInfo.erc20 == (address)(_gvToken),"lifeform: invalid stake token!" );
        require(extraInfo.erc721 == (address)(_adorn721),"lifeform: invalid _adorn721 !" );
        require(extraInfo.erc1155 == (address)(_adorn1155),"lifeform: invalid _adorn1155!" );

        if(extraInfo.erc20Amount>0){
            IERC20(extraInfo.erc20).safeTransferFrom(msg.sender, address(this), extraInfo.erc20Amount);
        }

        if(extraInfo.children721.length>0){
            IAdorn721(extraInfo.erc721).safeBatchTransferFrom(msg.sender, address(this), extraInfo.children721, "");
        }

        if(extraInfo.amount1155.length>0){
            IERC1155(extraInfo.erc1155).safeBatchTransferFrom(msg.sender, address(this), extraInfo.children1155, extraInfo.amount1155, "");
        }

        uint256 id = _avatar721.mint(msg.sender, extraInfo);

        emit Avatar721Mint(
                id,
                udIndex,
                // block.number,
                extraInfo.erc20,
                extraInfo.erc20Amount,
                extraInfo.erc721,
                extraInfo.children721,
                extraInfo.erc1155,
                extraInfo.children1155,
                extraInfo.amount1155,
                address(_avatar721),
                msg.sender
            );
    } 



    function burnAvatar721(uint256 tokenId) external nonReentrant {
      
        IAvatar721.ExtraInfo memory extraInfo = _avatar721.getExtraInfo(tokenId);
        address avatar721 = address(_avatar721);

        (IERC721)(avatar721).safeTransferFrom(msg.sender, address(this), tokenId);
        _avatar721.burn(tokenId);

        if(extraInfo.erc20Amount>0){
            (IERC20)(extraInfo.erc20).safeTransfer(msg.sender, extraInfo.erc20Amount);
        }

        if(extraInfo.children721.length>0){
            (IAdorn721)(extraInfo.erc721).safeBatchTransferFrom(address(this), msg.sender, extraInfo.children721 , "");
        }

        if(extraInfo.amount1155.length>0){
            (IERC1155)(extraInfo.erc1155).safeBatchTransferFrom(address(this), msg.sender, extraInfo.children1155 , extraInfo.amount1155, "");
        }

        emit Avatar721Burn(
                tokenId,
                // block.number,
                extraInfo.erc20,
                extraInfo.erc20Amount,
                extraInfo.erc721,
                extraInfo.children721,
                extraInfo.erc1155,
                extraInfo.children1155,
                extraInfo.amount1155,
                msg.sender,
                avatar721
            );
    }


    function withdrawETH(address target) external onlyOwner {
        payable(target).transfer(address(this).balance);
    }

    function urgencyWithdrawErc20(address erc20, address target) external onlyOwner {
        IERC20(erc20).safeTransfer(target, IERC20(erc20).balanceOf(address(this)));
    }

    function urgencyWithdrawErc721(address erc721, address target, uint256[] calldata ids) external onlyOwner {
        IAdorn721(erc721).safeBatchTransferFrom(address(this), target, ids,"");
    }

    function urgencyWithdrawErc1155(address erc1155, address target, uint256[] calldata ids,  uint256[] calldata amounts) external onlyOwner {
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
