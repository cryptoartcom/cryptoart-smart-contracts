// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";
import {IERC7160} from "../../src/interfaces/IERC7160.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract InitializationTest is CryptoartNFTBase {
    function test_InitializationSetsCorrecctValues() public view {
        // Test initialization sets values
        assertEq(nft.owner(), owner);
        assertEq(nft.authoritySigner(), authoritySigner);
        assertEq(nft.nftReceiver(), nftReceiver);
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.baseURI(), BASE_URI);

        // Test ERC721 metadat
        assertEq(nft.name(), "Cryptoart");
        assertEq(nft.symbol(), "CNFT");

        // Test deafult royalty settings
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 10_000);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, nft.DEFAULT_ROYALTY_PERCENTAGE());
    }

    function test_SupportsCorrectInterfaces() public view {
        // ERC165 interface ID
        bytes4 erc165InterfaceId = 0x01ffc9a7;
        // ERC721 interface ID
        bytes4 erc721InterfaceId = 0x80ac58cd;
        // ERC721Metadata interface ID
        bytes4 erc721MetadataInterfaceId = 0x5b5e139f;
        // ERC721Enumerable interface ID
        bytes4 erc721EnumerableInterfaceId = 0x780e9d63;
        // ERC2981 Royalty interface ID
        bytes4 erc2981InterfaceId = 0x2a55205a;
        // ERC4906 MetadataUpdate interface ID
        bytes4 erc4906InterfaceId = type(IERC4906).interfaceId;
        // ERC7160 interface ID
        bytes4 erc7160InterfaceId = type(IERC7160).interfaceId;

        // Check each interface is supported
        assertTrue(nft.supportsInterface(erc165InterfaceId));
        assertTrue(nft.supportsInterface(erc721InterfaceId));
        assertTrue(nft.supportsInterface(erc721MetadataInterfaceId));
        assertTrue(nft.supportsInterface(erc721EnumerableInterfaceId));
        assertTrue(nft.supportsInterface(erc2981InterfaceId));
        assertTrue(nft.supportsInterface(erc4906InterfaceId));
        assertTrue(nft.supportsInterface(erc7160InterfaceId));
    }

    function test_RevertWhenInitializedTwice() public {
        vm.expectRevert(abi.encodeWithSignature("InvalidInitialization()"));
        nft.initialize(owner, authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI);
    }

    function test_RevertWhenZeroAddressOwner() public {
        CryptoartNFT implementation = new CryptoartNFT();

        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector, address(0), authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI
        );

        vm.expectRevert(Error.Admin_ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_RevertWhenZeroAddressAuthoritySigner() public {
        CryptoartNFT implementation = new CryptoartNFT();

        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector, owner, address(0), nftReceiver, MAX_SUPPLY, BASE_URI
        );

        vm.expectRevert(Error.Admin_ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_RevertWhenZeroAddressNftReceiver() public {
        CryptoartNFT implementation = new CryptoartNFT();

        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector, owner, authoritySigner, address(0), MAX_SUPPLY, BASE_URI
        );

        vm.expectRevert(Error.Admin_ZeroAddress.selector);
        new ERC1967Proxy(address(implementation), initData);
    }

    function test_ConstructorDisablesInitializers() public {
        CryptoartNFT uninitNft = new CryptoartNFT();
        vm.expectRevert();
        uninitNft.initialize(owner, authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI);
    }
}
