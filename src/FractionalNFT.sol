// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

struct NFTVault {
    address owner;
    address nftAddress;
    uint256 tokenId;
    uint256 timeAdded;
    address fractionedERC;
    uint256 pricePerUnit;
    uint256 supply;
}

contract FractionERC is ERC20 {
    constructor(string memory _name, string memory _symbol, uint256 _supply) ERC20(_name, _symbol) {
        _mint(msg.sender, _supply);
    }
}

contract FractionalNFT is IERC721Receiver {
    mapping(address => NFTVault[]) private vaults;
    mapping(address => mapping(uint256 => uint256)) vaultIndex;
    uint256 constant OPERATING_FEE = 1;
    uint256 constant OP_FEE_DIVISIOR = 1000;
    address operator;

    constructor() {
        operator = msg.sender;
    }

    function createFraction(address _nftAddress, uint256 _tokenId, uint256 _totalWholeSupply, uint256 _pricePerUnit)
        external
    {
        IERC721 nftC = IERC721(_nftAddress);
        nftC.safeTransferFrom(msg.sender, address(this), _tokenId);

        vaultIndex[_nftAddress][_tokenId] = vaults[msg.sender].length;
        FractionERC f = new FractionERC("Fractional NFT", "FNT", _totalWholeSupply * 10e18);

        vaults[_nftAddress].push(
            NFTVault(msg.sender, _nftAddress, _tokenId, block.timestamp, address(f), _pricePerUnit, _totalWholeSupply)
        );
    }

    function buyFraction(address _nftAddress, uint256 _tokenId) external payable {
        require(msg.value > 0, "Zero Ether not allowed");
        uint256 _vaultIndex = vaultIndex[_nftAddress][_tokenId];
        NFTVault storage _vault = vaults[_nftAddress][_vaultIndex];
        FractionERC f = FractionERC(_vault.fractionedERC);
        uint256 units = _calculateUnits(msg.value, _vault.pricePerUnit, f.decimals());

        uint256 fee = msg.value * OPERATING_FEE / OP_FEE_DIVISIOR;

        payable(operator).transfer(fee);
        payable(_vault.owner).transfer(msg.value - fee);
        f.transfer(msg.sender, units);
    }

    function withdrawNFTWithTotalSupply(address _nftAddress, uint256 _tokenId) public {
        uint256 _vaultIndex = vaultIndex[_nftAddress][_tokenId];
        NFTVault storage _vault = vaults[_nftAddress][_vaultIndex];
        FractionERC f = FractionERC(_vault.fractionedERC);
        require(f.balanceOf(msg.sender) >= f.totalSupply(), "Not enough tokens");
        IERC721 nftC = IERC721(_nftAddress);

        nftC.safeTransferFrom(address(this), msg.sender, _tokenId);
    }

    function getVault(address _nftAddress, uint256 _tokenId) public view returns (NFTVault memory) {
        uint256 _vaultIndex = vaultIndex[_nftAddress][_tokenId];
        return vaults[_nftAddress][_vaultIndex];
    }

    function _calculateUnits(uint256 _amount, uint256 _pricePerUnit, uint8 _decimals) internal pure returns (uint256) {
        return (_amount * 10 ** _decimals) / _pricePerUnit;
    }

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
