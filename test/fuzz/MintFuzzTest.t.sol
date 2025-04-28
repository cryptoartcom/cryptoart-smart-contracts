// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Error} from "../../src/libraries/Error.sol";

contract MintFuzzTest is CryptoartNFTBase {
    function testFuzz_MintWithVariableTokenIdandPrice(uint256 tokenId, uint96 tokenPrice) public {
        vm.assume(tokenPrice > 0);
        vm.deal(user1, tokenPrice);

        mintNFT(user1, tokenId, tokenPrice, tokenPrice);
        assertEq(nft.ownerOf(tokenId), user1);
    }

    function testFuzz_MintWithVariablePricingAndPayment(uint256 tokenPrice, uint256 payment) public {
        // Bound price and payment to reasonable ranges to avoid overflows
        tokenPrice = bound(tokenPrice, 0.0001 ether, 100 ether);
        payment = bound(payment, 0, 200 ether);

        // Create mint data with customtokenPrice
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, tokenPrice, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);

        vm.deal(user1, payment);
        vm.startPrank(user1);

        if (payment < tokenPrice) {
            vm.expectRevert(abi.encodeWithSelector(Error.Mint_InsufficientPayment.selector, tokenPrice, payment));
            nft.mint{value: payment}(data, tokenURISet);
        } else {
            // Track balances to verify refund
            uint256 userBalanceBefore = user1.balance;
            uint256 contractBalanceBefore = address(nft).balance;

            nft.mint{value: payment}(data, tokenURISet);

            // Verify token minted successfully
            assertEq(nft.ownerOf(TOKEN_ID), user1);

            // Verify correct payment processed and excess refunded
            assertEq(address(nft).balance - contractBalanceBefore, tokenPrice);
            assertEq(user1.balance, userBalanceBefore - tokenPrice);
        }

        vm.stopPrank();
    }

    function testFuzz_MintWithDifferentMintTypes(uint8 mintMethod) public {
        vm.deal(user1, 1 ether);

        mintMethod = uint8(bound(mintMethod, 0, 3)); // only four mint methods
        uint256 tokenId = 999;
        
        uint8 openMint = 0;
        uint8 claim = 1;
        uint8 trade = 2;
        uint8 burn = 3;

        vm.startPrank(user1);

        // switch b/w different mint methods
        if (mintMethod == openMint) {
            (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) = createMintData(
                user1, tokenId, TOKEN_PRICE, CryptoartNFT.MintType(openMint), authoritySignerPrivateKey
            );
            nft.mint{value: TOKEN_PRICE}(data, tokenURISet);
            
        } else if (mintMethod == claim) {
            (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) = createMintData(
                user1, tokenId, TOKEN_PRICE, CryptoartNFT.MintType(claim), authoritySignerPrivateKey
            );
            nft.claim{value: TOKEN_PRICE}(data, tokenURISet);
            
        } else if (mintMethod == trade) {
            uint256[] memory tradedTokens = new uint256[](1);
            uint256 requiredTradeCount = tradedTokens.length;
            uint256 tradeTokenId = 888;
            uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;

            // First, mint the token
            (CryptoartNFT.MintValidationData memory mintData, CryptoartNFT.TokenURISet memory mintTokenURISet) =
                createMintData(user1, tradeTokenId, TOKEN_PRICE, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);
            nft.mint{value: TOKEN_PRICE}(mintData, mintTokenURISet);

            // Then, trade it to mint
            CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(tokenId);
            bytes memory signature = signingUtils.createMintSignature(
                user1,
                tokenId,
                CryptoartNFT.MintType(trade),
                authoritySignerPrivateKey,
                tokenURISet,
                TOKEN_PRICE,
                requiredTradeCount,
                nft.nonces(user1),
                deadline,
                address(nft)
            );
    
           CryptoartNFT.MintValidationData memory data = CryptoartNFT.MintValidationData({
                recipient: user1,
                tokenId: tokenId,
                tokenPrice: TOKEN_PRICE,
                mintType: CryptoartNFT.MintType(trade),
                requiredBurnOrTradeCount: requiredTradeCount,
                deadline: deadline,
                signature: signature
            });
           
            tradedTokens[0] = tradeTokenId;
            nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokens, data, tokenURISet);
            
        } else if (mintMethod == burn) {
            uint256[] memory burnTokens = new uint256[](1);
            uint256 requiredBurnCount = burnTokens.length;
            uint256 burnTokenId = 777;
            uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;

            // First, mint the token
            (CryptoartNFT.MintValidationData memory mintData, CryptoartNFT.TokenURISet memory mintTokenURISet) =
                createMintData(user1, burnTokenId, TOKEN_PRICE, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);
            nft.mint{value: TOKEN_PRICE}(mintData, mintTokenURISet);

            // Then, burn and mint a token
            CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(tokenId);
            bytes memory signature = signingUtils.createMintSignature(
                user1,
                tokenId,
                CryptoartNFT.MintType(burn),
                authoritySignerPrivateKey,
                tokenURISet,
                TOKEN_PRICE,
                requiredBurnCount,
                nft.nonces(user1),
                deadline,
                address(nft)
            );
    
            CryptoartNFT.MintValidationData memory data = CryptoartNFT.MintValidationData({
                recipient: user1,
                tokenId: tokenId,
                tokenPrice: TOKEN_PRICE,
                mintType: CryptoartNFT.MintType(burn),
                requiredBurnOrTradeCount: requiredBurnCount,
                deadline: deadline,
                signature: signature
            });
            
            burnTokens[0] = burnTokenId;
            nft.burnAndMint{value: TOKEN_PRICE}(burnTokens, data, tokenURISet);
        }

        vm.stopPrank();
    }

    function testFuzz_MintWithReentrancy() public {
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;
        uint256 requiredBurnCount = 1;

        // Create the attacker contract
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(nft));
        vm.deal(address(attacker), 3 ether);

        // First mint a token to burn
        uint256 burnTokenId = 777;
        vm.prank(user1);
        mintNFT(user1, burnTokenId, TOKEN_PRICE, TOKEN_PRICE);

        // Transfer the token to the attacker
        vm.prank(user1);
        nft.transferFrom(user1, address(attacker), burnTokenId);

        // Create mint data for a new token
        uint256 newTokenId = 999;
        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(newTokenId);

        // Get a proper signature
        bytes memory signature = signingUtils.createMintSignature(
            address(attacker),
            newTokenId,
            CryptoartNFT.MintType.Burn,
            authoritySignerPrivateKey,
            tokenURISet,
            TOKEN_PRICE,
            requiredBurnCount,
            nft.nonces(address(attacker)),
            deadline,
            address(nft)
        );

        CryptoartNFT.MintValidationData memory data = CryptoartNFT.MintValidationData({
            recipient: address(attacker),
            tokenId: newTokenId,
            tokenPrice: TOKEN_PRICE,
            mintType: CryptoartNFT.MintType.Burn,
            requiredBurnOrTradeCount: requiredBurnCount,
            deadline: deadline,
            signature: signature
        });

        // Set up the attacker to try reentrancy
        attacker.setupBurnMintAttack(burnTokenId, data, tokenURISet);

        // Execute the attack
        vm.prank(address(attacker));
        attacker.executeBurnAndMint();

        // We should have attempted to reenter but failed due to the guard
        assertTrue(attacker.attemptedReentrancy(), "Reentrancy should have been attempted");
        assertFalse(attacker.successfulReentrancy(), "Reentrancy should have failed");

        // Verify the burn and mint worked correctly
        vm.expectRevert(); // Should revert when checking owner of burned token
        nft.ownerOf(burnTokenId);

        assertEq(nft.ownerOf(newTokenId), address(attacker), "New token should be owned by attacker");
    }
}

contract ReentrancyAttacker {
    CryptoartNFT private nft;
    bool public attempted = false;
    bool public succeeded = false;

    // Attack data
    uint256 private burnTokenId;
    uint256[] private burnTokenIds;
    CryptoartNFT.MintValidationData private mintData;
    CryptoartNFT.TokenURISet private tokenURISet;

    constructor(address _nft) {
        nft = CryptoartNFT(_nft);
    }

    function setupBurnMintAttack(
        uint256 _burnTokenId,
        CryptoartNFT.MintValidationData memory _mintData,
        CryptoartNFT.TokenURISet memory _tokenURISet
    ) external {
        burnTokenId = _burnTokenId;
        mintData = _mintData;
        tokenURISet = _tokenURISet;

        // Prepare array for burn operation
        burnTokenIds = new uint256[](1);
        burnTokenIds[0] = _burnTokenId;
    }

    function executeBurnAndMint() external payable {
        nft.burnAndMint{value: mintData.tokenPrice}(
            burnTokenIds,
            mintData,
            tokenURISet
        );
    }

    // This checks if reentrancy was attempted
    function attemptedReentrancy() external view returns (bool) {
        return attempted;
    }

    // This checks if reentrancy was successful
    function successfulReentrancy() external view returns (bool) {
        return succeeded;
    }

    // ERC721 callback where we attempt reentrancy
    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        if (msg.sender == address(nft)) {
            attempted = true;

            // Try to reenter
            try nft.burnAndMint{value: 0.1 ether}(burnTokenIds, mintData, tokenURISet) {
                // If this succeeds, reentrancy worked
                succeeded = true;
            } catch {
                // Expected to fail due to reentrancy guard
            }
        }

        return this.onERC721Received.selector;
    }

    // Fallback for refunds
    receive() external payable {}
}
