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
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./Interface/IAdorn1155.sol";

contract Adorn1155 is ERC1155, Ownable,IAdorn1155 {

    using Strings for uint256;

    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;

    string public _name;
    string public _symbol;
    string public _baseURI =  "https://ipfs.lifeform.cc/bsc/adorn1155/token/";
    string public _metatype =  ".json";

    mapping(uint256 => EnumerableSet.AddressSet) private _holderInfo;
    EnumerableSet.UintSet private _ids;

    mapping(address => bool) public _minters;

    modifier onlyMinter() {
        require(_minters[msg.sender], "must call by minter");
        _;
    }

    constructor( address factory, string memory name,string memory symbol, string memory baseURI, string memory metatype) 
    ERC1155(baseURI) 
    {
        _name=name;
        _symbol=symbol;
        _metatype = metatype;
        _baseURI = baseURI;

        addMinter(factory);
        addMinter(owner());
    }

    /**
     * @dev function to grant permission to a minter
     */
    function addMinter(address minter) public onlyOwner {
        _minters[minter] = true;
    }

    /**
     * @dev function to remove permission to a minter
     */
    function removeMinter(address minter) public onlyOwner {
        _minters[minter] = false;
    }

    /**
     * @dev function to set the metadata file type
     */
    function setMetaType(string memory metatype) public onlyOwner{
        _metatype = metatype;
    }

    /**
     * @dev function to set a base url of the metadata
     */
    function setURI(string memory baseURI) public  onlyOwner
    {
        _baseURI = baseURI;
        _setURI(baseURI);
    }

    /**
     * @dev function to get the metadata url by tokenId
     */
    function uri(uint256 tokenId) public view virtual override returns (string memory) {
        require(_ids.contains(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return bytes(_baseURI).length > 0 ? string(abi.encodePacked(_baseURI, tokenId.toString(), _metatype)) : "";
    }


    /**
     * @dev function to mint tokens.
     * @param account The address that will receive the minted token.
     * @param tokenId The token id to mint.
     * @param amount The token amount to mint.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received}, which is called upon a safe transfer.
     */
    function mint(address account, uint256 tokenId, uint256 amount, bytes memory data) external onlyMinter
    {
        _mint(account, tokenId, amount, data);

        if(!_holderInfo[tokenId].contains(account)){
            _holderInfo[tokenId].add(account);
        }

        if(!_ids.contains(tokenId)){
            _ids.add(tokenId);
        }
    }


    /**
     * @dev function to batch mint tokens.
     * @param account The address that will receive the minted token.
     * @param tokenIds The token id to mint.
     * @param amounts The token amount to mint.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received}, which is called upon a safe transfer.
     */
    function mintBatch(address account, uint256[] memory tokenIds, uint256[] memory amounts, bytes memory data) external onlyMinter
     {
        _mintBatch(account, tokenIds, amounts, data);

        for(uint i=0; i<tokenIds.length; i++){
            if(!_holderInfo[tokenIds[i]].contains(account)){
                _holderInfo[tokenIds[i]].add(account);
            }
            
            if(!_ids.contains(tokenIds[i])){
                _ids.add(tokenIds[i]);
            }
        }
    }

    /**
     * @dev function to burn a specific ERC1155 token.
     * @param account The address that will burn token.
     * @param tokenId uint256 id of the ERC1155 token to be burned.
     */
    function burn(address account, uint256 tokenId, uint256 amount) external onlyMinter
     {
        require( account == msg.sender ||  isApprovedForAll(account,msg.sender), "ERC1155: transfer caller is not owner nor approved");
        _burn(account, tokenId, amount);

        if(balanceOf(account,tokenId)==0){
            _holderInfo[tokenId].remove(account);
        }
    }

    /**
     * @dev function to batch burn a specific ERC1155 tokens.
     * @param account The address that will burn token.
     * @param tokenId uint256 id of the ERC1155 tokens to be burned.
     * @param amounts the amount of the ERC1155 tokens to be burned.
     */
    function burnBatch(address account, uint256[] memory tokenIds, uint256[] memory amounts) external onlyMinter
     {
        require( account == msg.sender || isApprovedForAll(account,msg.sender), "ERC1155: transfer caller is not owner nor approved");
        _burnBatch(account, tokenIds, amounts);

        for(uint i=0; i<tokenIds.length; i++){
            if(balanceOf(account,tokenIds[i])==0){
                _holderInfo[tokenIds[i]].remove(account);
            }
        }
    }

    /**
     * @dev function to get the list of token IDs of the requested owner.
     * @param owner the tokens owner address
     * @param offset page index
     * @param pageMax the max count of one page
     */
     function tokensOfOwner(address owner, uint256 offset, uint256 pageMax ) external view returns ( IAdorn1155.NftInfo1155[] memory nftInfos) {

        require(pageMax>0, "invalid page size!");
        
        uint256 balance = _ids.length();
        uint256 maxCount = 0;
        if(balance <= pageMax){
            maxCount = balance;
        }
        else{
            maxCount = pageMax;
            uint256 pages = balance/pageMax;
        
            require(pages>=offset, "invalid page size!");

            if(pages == offset){
                maxCount = balance%pageMax;
                require(maxCount > 0, "invalid page size!");
            }
        }

        nftInfos = new IAdorn1155.NftInfo1155[](maxCount);
        for (uint i=0; i<maxCount; i++) {
            nftInfos[i].id = _ids.at(offset*pageMax+i);
            nftInfos[i].amount = balanceOf(owner, _ids.at(offset*pageMax+i) );
        }

    }

    /**
     * @dev function to get the all of the ids.
     */
    function totalIds() external  view returns ( uint256[] memory ids ) {
        
        uint maxCount = _ids.length();
        ids = new uint256[](maxCount);
        for(uint i=0; i<maxCount; i++){
            ids[i] = _ids.at(i);
        }
        return ids;
    }

    /**
     * @dev function to get the holder count by id.
     */
    function holderCount(uint256 id) external  view returns ( uint256 ) {
        return _holderInfo[id].length();
    }

}