// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";

contract AdminTest is CryptoartNFTBase {
    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        nft.pause();
        assertTrue(nft.paused());
        nft.unpause();
        assertFalse(nft.paused());
        vm.stopPrank();
    }

    function test_RevertWhenNonOwnerPause() public {
        vm.expectRevert();
        vm.prank(user1);
        nft.pause();
    }

    function test_RevertWhennonOwnerUnpause() public {
        vm.prank(owner);
        nft.pause();
        vm.expectRevert();
        vm.prank(user1);
        nft.unpause();
    }

    function test_UpdateRoyalties() public {
        address newReceiver = makeAddr("newReceiver");
        uint96 newPercentage = 500; // 5%
        vm.prank(owner);
        nft.updateRoyalties(payable(newReceiver), newPercentage);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, newReceiver);
        assertEq(royaltyAmount, 500); // 5% of 10,000
    }

    function test_RevertWhenRoyaltyTooHigh() public {
        address newReceiver = makeAddr("newReceiver");
        uint96 tooHighPercentage = 10_001; // < 100%
        vm.expectRevert();
        vm.prank(owner);
        nft.updateRoyalties(payable(newReceiver), tooHighPercentage);
    }

    function test_RevertWhennonownerUpdatesRoyalties() public {
        address newReceiver = makeAddr("newReceiver");
        uint96 newPercentage = 500;
        vm.expectRevert();
        vm.prank(user1);
        nft.updateRoyalties(payable(newReceiver), newPercentage);
    }

    function test_SetBaseURI() public {
        string memory newBaseURI = "https://some.test.com/";
        vm.prank(owner);
        nft.setBaseURI(newBaseURI);
        assertEq(nft.baseURI(), newBaseURI);
    }

    function test_RevertWhenNonOwnerSetsBaseURI() public {
        string memory newBaseURI = "https://some.test.com/";
        vm.expectRevert();
        vm.prank(user1);
        nft.setBaseURI(newBaseURI);
    }

    function test_UpdateAuthoritySigner() public {
        address newAuthoritySigner = makeAddr("newAuthoritySigner");
        vm.prank(owner);
        nft.updateAuthoritySigner(newAuthoritySigner);
        assertEq(newAuthoritySigner, nft.authoritySigner());
    }

    function test_RevertWhenNonOwnerUpdatesAuthoritySigner() public {
        address newAuthoritySigner = makeAddr("newAuthoritySigner");
        vm.expectRevert();
        vm.prank(user1);
        nft.updateAuthoritySigner(newAuthoritySigner);
    }

    function test_UpdateNftReceiver() public {
        address newNftReceiver = makeAddr("newNftReceeiver");
        vm.prank(owner);
        nft.updateNftReceiver(newNftReceiver);
        assertEq(newNftReceiver, nft.nftReceiver());
    }

    function test_RevertWhenNonOwnerUpdatesNftReceiver() public {
        address newNftReceiver = makeAddr("newNftReceeiver");
        vm.expectRevert();
        vm.prank(user1);
        nft.updateNftReceiver(newNftReceiver);
    }

    function test_SetMaxSupply() public {
        uint128 newMaxSupply = 100_000;
        vm.prank(owner);
        nft.setMaxSupply(newMaxSupply);
        assertEq(newMaxSupply, nft.maxSupply());
    }

    function test_RevertWhenNonOwnerSetsMaxSupply() public {
        uint128 newMaxSupply = 100_000;
        vm.expectRevert();
        vm.prank(user1);
        nft.setMaxSupply(newMaxSupply);
    }

    function test_WithdrawFunds() public {
        // add funds to contract
        vm.deal(address(nft), 1 ether);
        uint256 ownerBalanceBefore = owner.balance;
        vm.prank(owner);
        nft.withdraw();
        uint256 ownerBalanceAfter = owner.balance;

        assertEq(1 ether, ownerBalanceBefore);
        assertEq(2 ether, ownerBalanceAfter);
        assertEq(0 ether, address(nft).balance);
    }

    function test_RevertWhenNoFundsToWithdraw() public {
        assertEq(address(nft).balance, 0 ether);
        vm.expectRevert();
        vm.prank(owner);
        nft.withdraw();
    }

    function test_RevertWhenNonOwnerWithdrawsFunds() public {
        vm.deal(address(nft), 1 ether);
        vm.expectRevert();
        vm.prank(user1);
        nft.withdraw();
    }

    function test_RevertWhenWithdrawFailes() public {
        vm.deal(address(nft), 1 ether);

        // create a contract that rejects paymetns
        address payable receiverContract = payable(address(new PaymentRejector()));

        // transfer ownership to rejecting contract
        vm.prank(owner);
        nft.transferOwnership(receiverContract);

        // try to withdraw
        vm.prank(receiverContract);
        vm.expectRevert(abi.encodeWithSelector(Error.Admin_WithdrawalFailed.selector, receiverContract, 1 ether));
        nft.withdraw();
    }

    function test_EmitsEventsForAdminFunctions() public {
        vm.startPrank(owner);

        // Test BaseURISet event
        vm.expectEmit(false, false, false, true);
        emit CryptoartNFT.BaseURISet("https://newuri.com/");
        nft.setBaseURI("https://newuri.com/");

        // Test MaxSupplySet event
        vm.expectEmit(false, false, false, true);
        emit CryptoartNFT.MaxSupplySet(20000);
        nft.setMaxSupply(20000);

        // Test RoyaltiesUpdated event
        address newRoyaltyReceiver = makeAddr("royaltyReceiver");
        vm.expectEmit(true, false, false, true);
        emit CryptoartNFT.RoyaltiesUpdated(newRoyaltyReceiver, 300);
        nft.updateRoyalties(payable(newRoyaltyReceiver), 300);

        // Test AuthoritySignerUpdated event
        address newSigner = makeAddr("newSigner");
        vm.expectEmit(false, false, false, true);
        emit CryptoartNFT.AuthoritySignerUpdated(newSigner);
        nft.updateAuthoritySigner(newSigner);

        // Test NftReceiverUpdated event
        address newReceiver = makeAddr("newReceiver");
        vm.expectEmit(false, false, false, true);
        emit CryptoartNFT.NftReceiverUpdated(newReceiver);
        nft.updateNftReceiver(newReceiver);

        vm.stopPrank();
    }
}

contract PaymentRejector {
    // rejects all payments
    receive() external payable {
        revert();
    }

    // allow calling the NFT ccontract
    fallback() external payable {}
}
