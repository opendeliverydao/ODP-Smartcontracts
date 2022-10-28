// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IOdpResourceAllocation {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
    function withdraw(uint256 wad, address user) external;
}

contract ODPStore is ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    //Prices in NATIVE CURRENCY (ETH/MATIC/BNB)
    uint256 public currentCreatePrice = 200000000000000000;
    uint256 public currentUpdatePrice = 100000000000000000;
    uint256 public currentChangeCodeNamePrice = 400000000000000000;

    IOdpResourceAllocation public odpResourceAllocationAddress;
    
    string appBaseUri;
    string contractMetaData;
    bool ownerCanBurn=true;

    mapping(string => uint256) public codeName_to_tokenId;
    mapping(uint256 => string) public tokenId_to_hashCustomerApp;
    mapping(uint256 => string) public tokenId_to_codeName;

    constructor(
        string memory _appBaseUri,
        string memory _contractMetaData,
        address _odpResourceAllocationAddress
    ) ERC721("ODP Store Token", "ODPST") {
        appBaseUri = _appBaseUri;
        contractMetaData = _contractMetaData;
        odpResourceAllocationAddress = IOdpResourceAllocation(_odpResourceAllocationAddress);
    }

    function updateCurrentCreatePrice(uint256 newPrice) public onlyOwner {
        currentCreatePrice = newPrice;
    }

    function updateCurrentUpdatePrice(uint256 newPrice) public onlyOwner {
        currentUpdatePrice = newPrice;
    }

    function updateCurrentChangeCodeNamePrice(uint256 newPrice) public onlyOwner {
        currentChangeCodeNamePrice = newPrice;
    }

    function updateBaseUri(string memory newBaseUri) public onlyOwner {
        appBaseUri = newBaseUri;
    }

    function updateContractMetaUri(string memory newUri) public onlyOwner {
        contractMetaData = newUri;
    }

    function renouceBurnPrivilege() public onlyOwner {
        ownerCanBurn=false;
    }

    function updateTokenCodename(string memory codename,uint256 tokenId) public payable {
        require(codeName_to_tokenId[codename] == 0, "Code name is not available");
        require(msg.sender == ownerOf(tokenId));
        string memory lastCodename=tokenId_to_codeName[tokenId];
        codeName_to_tokenId[codename]=tokenId;
        codeName_to_tokenId[lastCodename]=0;
        tokenId_to_codeName[tokenId]=codename;
        odpResourceAllocationAddress.deposit{value:currentChangeCodeNamePrice}();
    }

    function updateTokenURI(string memory newUri,uint256 tokenId) public payable {
        require(msg.sender == ownerOf(tokenId));
        tokenId_to_hashCustomerApp[tokenId]=newUri;
        odpResourceAllocationAddress.deposit{value:currentUpdatePrice}();
    }

    function transfer(address to, uint256 amount) public onlyOwner {
        payable(to).transfer(amount);
    }

    function burn(uint256 tokenId) public {
        require(msg.sender == ownerOf(tokenId)||(msg.sender==owner() &&  ownerCanBurn ),"not token owner or contract owner");
        string memory lastCodename=tokenId_to_codeName[tokenId];
        codeName_to_tokenId[lastCodename]=0;
        tokenId_to_hashCustomerApp[tokenId] = "";
        _burn(tokenId);
    }

    function setApproval(address tokenAddress, address guy, uint256 amount) public onlyOwner {
        IERC20(tokenAddress).approve(guy, amount);   
    }

    function createNewStore(string memory codename, string memory ipfs_app)
        public
        payable
        returns (uint256)
    {
        require(codeName_to_tokenId[codename] == 0, "Code name is not available");

        uint256 tokenId = _tokenIds.current()+1;
        _safeMint(msg.sender, tokenId);
        odpResourceAllocationAddress.deposit{value:currentCreatePrice}();
        _tokenIds.increment();

        codeName_to_tokenId[codename] = tokenId;
        tokenId_to_codeName[tokenId] = codename;

        tokenId_to_hashCustomerApp[tokenId] = ipfs_app;
        
        
        return tokenId;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        
        returns (string memory)
    {
        
        return
            string(
                abi.encodePacked(
                    appBaseUri,
                    tokenId_to_hashCustomerApp[tokenId]
                )
            );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return appBaseUri;
    }

    function contractURI() public view returns (string memory) {
        return contractMetaData;
    }
}
