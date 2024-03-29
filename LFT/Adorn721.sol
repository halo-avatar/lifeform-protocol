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

import "@openzeppelin/contracts/access/Ownable.sol";

import "./Interface/IAdorn721.sol";
import "../lib/ERC721A.sol";

contract Adorn721 is ERC721A, Ownable,IAdorn721 {
    
    using Strings for uint256;
    
    string public _baseUri =  "https://ipfs.lifeform.cc/bsc/adorn721/token/";
    string public _metatype =  ".json";

    mapping(address => bool) public _minters;

    modifier onlyMinter() {
        require(_minters[msg.sender], "must call by minter");
        _;
    }

    ////////////////////////////////////////////////////////////////////////
    constructor(string memory name,string memory symbol,string memory base, string memory metatype) 
        ERC721A(name, symbol) {
        _baseUri = base;
        _metatype = metatype; 

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
    function setBaseURI(string memory uri) public onlyOwner {
        _baseUri = uri;
    }

    /**
     * @dev function to get the minted number of the address.
     */
    function mintedNumber(address addr) external override view returns(uint256) {
        return _numberMinted(addr);
    }

     /**
     * @dev function to batch transfer tokens.
     * @param from The address that will transfer tokens.
     * @param to The address that will receive the tokens.
     * @param ids The token ids to be transfered.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     */
    function safeBatchTransferFrom(address from, address to, uint256[] memory ids, bytes memory data ) external override
    {
        for (uint256 i = 0; i < ids.length; ++i) {
            safeTransferFrom(from, to,ids[i],data);
        }
        emit TransferBatch(from, to, ids);
    }
    

    /**
     * @dev function to batch mint 
     */
    function batchMint(address target, uint256 amount) public onlyOwner {
        _safeMint(target, amount, "");
    }


    /**
     * @dev function to mint tokens.
     * @param to The address that will receive the minted token.
     * @param amount The token quantity to mint.
     */
    function mint(address to, uint256 amount) external override  onlyMinter returns  (uint256 mintStartId)
    {
        mintStartId=_currentIndex;
        _safeMint(to, amount, "");
    }

    /**
     * @dev function to burn a specific ERC721 token.
     * @param tokenId uint256 id of the ERC721 token to be burned.
     */
    function burn(uint256 tokenId) external override  onlyMinter
    {
        require(
            _isApprovedOrOwner(tokenId),
            "caller is not owner nor approved"
        );

        _burn(tokenId);
    }


    /**
     * @dev function to get the list of token IDs of the requested owner.
     */
    function listMyNFT(address owner) public view returns (uint256[] memory tokens) {
        uint256 owned = balanceOf(owner);
        tokens = new uint256[](owned);
        uint256 start = 0;
        for (uint256 i=0; i<_currentIndex; i++) {
            if(_ownerships[i].addr == owner && !_ownerships[i].burned){
                tokens[start] = i;
                start++;
            }
        }
    }

    /**
     * @dev The function returns the list of tokens IDs after the token ID(pageMax*offset)
     * @param owner the tokens owner address
     * @param offset page index
     * @param pageMax the max count of one page
     */
    function tokensOfOwner(address owner, uint256 offset, uint256 pageMax ) external override view  returns (uint256[] memory tokens) {

        require(pageMax>0, "invalid page size!");
        
        uint256 balance = balanceOf(owner);
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
       
        tokens = new uint256[](maxCount);
        uint256[] memory allhave = listMyNFT(owner);
        
        for(uint256 i=0; i<maxCount; i++){
            tokens[i] = allhave[offset*pageMax+i];
        }
    }

    /**
     * @dev function to get the metadata url by tokenId
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), _metatype)) : "";
    }

    /**
     * @dev function to check the owner with a nftid
     */
    function isOwner(uint256 nftID, address owner) public view returns(bool isNFTOwner) {
        address tokenOwner = ownerOf(nftID);
        isNFTOwner = (tokenOwner == owner);
    }

    /**
     * @dev function to get the oership info by tokenId.
     */
    function getOwnershipOf(uint256 tokenId) public view  returns (TokenOwnership  memory) {
        return _ownerships[tokenId];
    }
    
    /**
     * @dev IERC165-supportsInterface
     */
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev _baseURI override
     */
    function _baseURI() internal view override returns (string memory) {
        return _baseUri;
    }

    /**
     * @dev function to check the approve state 
     */
    function _isApprovedOrOwner( uint256 tokenId) internal view virtual returns (bool ) {

        TokenOwnership memory prevOwnership = ownershipOf(tokenId);

        bool isApprovedOrOwner = (_msgSender() == prevOwnership.addr ||
            isApprovedForAll(prevOwnership.addr, _msgSender()) ||
            getApproved(tokenId) == _msgSender());

        return isApprovedOrOwner;
    }
}