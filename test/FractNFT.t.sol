// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {NFTVault, FractionalNFT} from "../src/FractionalNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract MockNft is ERC721("Mock", "mck") {
    uint256 tokenId;

    function mint(address _to) public returns (uint256 _tokenId) {
        _tokenId = tokenId;
        _safeMint(_to, _tokenId);
        tokenId++;
    }
}

contract FractionalNFTTest is Test {
    FractionalNFT fractionalNFT;
    MockNft mockNft;
    IERC20 fToken;
    uint256 op_priv = 12345;
    address operator = vm.addr(op_priv);

    function setUp() public {
        vm.prank(operator);
        fractionalNFT = new FractionalNFT();
        mockNft = new MockNft();
    }

    function testCreateFraction() public {
        address userA = vm.addr(123);
        uint256 tokenId = _giveMockNft(userA);
        vm.startPrank(userA);
        mockNft.approve(address(fractionalNFT), tokenId);
        fractionalNFT.createFraction(address(mockNft), tokenId, 10, 1 ether);
        NFTVault memory _vault = fractionalNFT.getVault(address(mockNft), tokenId);
        fToken = IERC20(_vault.fractionedERC);
        vm.stopPrank();
    }

    function testBuyFraction() public {
        address userB = vm.addr(14523);
        testCreateFraction();
        startHoax(userB);
        uint256 balB4 = fToken.balanceOf(userB);
        fractionalNFT.buyFraction{value: 1 ether}(address(mockNft), 0);
        vm.stopPrank();
        uint256 bal = fToken.balanceOf(userB);
        assertGt(bal, balB4);
        assertEq(operator.balance, 1 ether / 1000);
    }

    function testClaimNFT() public {
        address userB = vm.addr(14523);
        testCreateFraction();
        startHoax(userB, 10 ether);
        fractionalNFT.buyFraction{value: 10 ether}(address(mockNft), 0);
        fractionalNFT.withdrawNFTWithTotalSupply(address(mockNft), 0);
    }

    function _giveMockNft(address _user) internal returns (uint256 _id) {
        _id = mockNft.mint(_user);
    }
}
