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

import "./IAdorn721.sol";
import "./IAdorn1155.sol";
import "./IAvatar721.sol";

interface IAvatarMintRule  {

    event NFT721Received(address operator, address from, uint256 tokenId, bytes data);
    event NFT1155Received(address operator, address from, uint256 tokenId, uint256 amount, bytes data);
    event NFT1155BatchReceived(address operator, address from, uint256[] tokenIds, uint256[] amounts, bytes data);

    event Avatar721Mint(
        uint256 id,
        uint256 udIndex,
        uint256 costErc20Amount,
        uint256 stakeErc20Amount,
        uint256[] children721,
        uint256[] children1155,
        uint256[] amount1155,
        address mintRule,
        address auther,
        address nftContract
    );

    event Avatar721Burn(
        uint256 id,
        address erc20,
        uint256 erc20Amount,
        address erc721,
        uint256[] children721,
        address erc1155,
        uint256[] children1155,
        uint256[] amount1155,
        address auther,
        address nftContract
        
    );

    struct MintRule {
        address mintRule;
        uint256 udIndex;
        address stakeErc20;
        uint256 stakeErc20Amount;
        address costErc20;
        uint256 costErc20Amount;
        address erc721;
        uint256 [] children721;
        address erc1155;
        uint256 [] children1155;
        uint256 [] amount1155;
        bytes32 signCode;
        bytes wlSignature;    //wlSignature
    }

    function mint( MintRule calldata mintData) external;

}