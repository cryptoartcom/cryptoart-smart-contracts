import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { CryptoartNFT as CryptoArtNFT } from "../typechain-types";
import { MockReceiver } from "../typechain-types/contracts/MockReceiver";

// mint types
type mintTypes = "openMint" | "whitelist" | "claimable" | "burn";
enum MintTypesEnum {
	OpenMint = "openMint",
	Whitelist = "whitelist",
	Claimable = "claimable",
	Burn = "burn",
}

// token data
const _tokenId1 = 1;
const _tokenId2 = 2;
const redeemableTrueURI = "https://ipfs.io/ipfs/QmZ";
const redeemableFalseURI = "https://ipfs.io/ipfs/QmY";

// wallets
const _owner = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);
const _signerAuthorityWallet = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);
const _priceInWei = ethers.parseEther("0.001");

const getSignatureForMint = async (
	contractAddress: CryptoArtNFT,
	minter: any,
	id: any,
	mintType: mintTypes = "openMint",
	priceInWei: bigint = _priceInWei,
	burnsToUse: number = 0,
	signer: HardhatEthersSigner | null = null,
	redeemableIndex: number = 0
) => {
	const signerAuthority = signer ?? _signerAuthorityWallet;
	const nonce = await contractAddress.nonces(minter);
	const chainId = network.config.chainId;
	const verifyingContract = contractAddress.target;

	const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
		[
			"address",
			"uint256",
			"string",
			"uint256",
			"uint256",
			"string",
			"string",
			"uint256",
			"uint256",
			"uint256",
			"address",
		],
		[
			minter,
			id,
			mintType,
			priceInWei,
			burnsToUse,
			redeemableTrueURI,
			redeemableFalseURI,
			redeemableIndex,
			nonce,
			chainId,
			verifyingContract,
		]
	);

	const digest = ethers.getBytes(ethers.keccak256(encodedData));

	const signature = await signerAuthority.signMessage(digest);

	return {
		minter,
		id,
		signature,
	};
};

const getSignatureForUnpair = async (
	contractAddress: CryptoArtNFT,
	minter: any,
	id: any,
	signer: HardhatEthersSigner | null = null
) => {
	const signerAuthority = signer ?? _signerAuthorityWallet;
	const nonce = await contractAddress.nonces(minter);
	const chainId = network.config.chainId;
	const verifyingContract = contractAddress.target;

	const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
		["address", "uint256", "uint256", "uint256", "address"],
		[minter, id, nonce, chainId, verifyingContract]
	);

	const digest = ethers.getBytes(ethers.keccak256(encodedData));

	const signature = await signerAuthority.signMessage(digest);

	return {
		minter,
		id,
		signature,
	};
};

describe("CryptoartNFT", function () {
	let cryptoArtNFT: CryptoArtNFT;
	let addr1: HardhatEthersSigner;
	let addr2: HardhatEthersSigner;
	let fakeSigner: HardhatEthersSigner;

	beforeEach(async function () {
		[addr1, addr2, fakeSigner] = await ethers.getSigners();
		const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoartNFT");
		const proxyContract = await upgrades.deployProxy(
			CryptoArtNFTFactory,
			[_owner.address, _signerAuthorityWallet.address],
			{
				initializer: "initialize",
			}
		);
		cryptoArtNFT = proxyContract as unknown as CryptoArtNFT;
	});

	beforeEach(async function () {
		// Get array of signers
		const [defaultAccount] = await ethers.getSigners();

		// Send amount of ETH
		const amount = ethers.parseEther("10"); // Change to desired amount

		// Send transaction from default account (with a lot of ETH) to _owner
		const tx = await defaultAccount.sendTransaction({
			to: _owner.address,
			value: amount,
		});

		// Wait for the transaction to finish
		await tx.wait();
	});

	describe("Deployment", function () {
		it("Should set the right Owner & Authority Signer", async function () {
			expect(await cryptoArtNFT.owner()).to.equal(_owner.address);
			expect(await cryptoArtNFT.currentAuthoritySigner()).to.equals(
				_signerAuthorityWallet.address
			);
		});
	});

	describe("Minting", function () {
		it("Mint only if valid signature: valid", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Emits a Minted event when minting a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			)
				.to.emit(cryptoArtNFT, "Minted")
				.withArgs(id);
		});

		it("Should revert when not enough Ether is sent to mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			const insufficientPrice = _priceInWei - 1n;

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: insufficientPrice,
						}
					)
			).to.be.revertedWith("Not enough Ether to mint NFT.");
		});

		it("Mint only if valid signature: invalid signer", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0,
				fakeSigner
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Mint only if valid signature: invalid parameters mismatch", async function () {
			const { signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable
			);

			// mismatch token
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						_tokenId2,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.be.revertedWith("Not authorized to mint");

			// mismatch wallet
			await expect(
				cryptoArtNFT
					.connect(addr2)
					.mint(
						_tokenId1,
						MintTypesEnum.Whitelist,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.be.revertedWith("Not authorized to mint");

			// mismatch token and wallet
			await expect(
				cryptoArtNFT
					.connect(addr2)
					.mint(
						_tokenId2,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Mint only if valid signature: invalid signature (signature for other user)", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				"openMint",
				_priceInWei,
				0,
				fakeSigner
			);

			await expect(
				cryptoArtNFT
					.connect(addr2)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Mint only if signature was not already used", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.not.be.reverted;
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Token already minted.");

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint only if signature was not already used by other token Id", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.not.be.reverted;
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						_tokenId2,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not authorized to mint");

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint only if token was not burnt", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.not.be.reverted;
			await expect(cryptoArtNFT.connect(addr1).burn(id));
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});

		it("Mint only if enough ETH: valid", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint only if enough ETH: not enough eth", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.01"),
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint with redeemability set on true by default", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0,
				null,
				0
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableTrueURI);
		});

		it("Mint with redeemability set on false by default", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0,
				null,
				1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						1,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableFalseURI);
		});
	});

	describe("Nonce", function () {
		it("Nonce increment after successful tx", async function () {
			const nonceBeforeSuccessfullyMint = await cryptoArtNFT.nonces(
				addr1.address
			);

			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const nonceAfterSuccessfullyMint = await cryptoArtNFT.nonces(
				addr1.address
			);
			expect(nonceBeforeSuccessfullyMint + 1n).equal(
				nonceAfterSuccessfullyMint
			);
		});
	});

	describe("Interface Support", function () {
		it("Should support ERC721 interface", async function () {
			expect(await cryptoArtNFT.supportsInterface("0x80ac58cd")).to.be.true;
		});

		it("Should support ERC721Metadata interface", async function () {
			expect(await cryptoArtNFT.supportsInterface("0x5b5e139f")).to.be.true;
		});

		it("Should support IERC165 interface", async function () {
			expect(await cryptoArtNFT.supportsInterface("0x49064906")).to.be.true;
		});
	});

	describe("Royalties", function () {
		it("Should return correct royalty info", async function () {
			const tokenId = 1;
			const salePrice = ethers.parseEther("1");
			const [receiver, royaltyAmount] = await cryptoArtNFT.royaltyInfo(
				tokenId,
				salePrice
			);
			const royaltyPercentage = await cryptoArtNFT.royaltyPercentage();

			expect(receiver).to.equal(_owner.address);
			expect(royaltyAmount).to.equal((salePrice * royaltyPercentage) / 10000n); // Assuming 2.5% royalty
		});

		it("Should update royalties", async function () {
			const newRoyaltyPercentage = 750; // 7.5%
			await expect(
				cryptoArtNFT
					.connect(_owner)
					.updateRoyalties(_owner, newRoyaltyPercentage)
			)
				.to.emit(cryptoArtNFT, "RoyaltiesUpdated")
				.withArgs(_owner, newRoyaltyPercentage);

			const tokenId = 1;
			const salePrice = ethers.parseEther("1");
			const [, royaltyAmount] = await cryptoArtNFT.royaltyInfo(
				tokenId,
				salePrice
			);
			expect(royaltyAmount).to.equal((salePrice * 75n) / 1000n);
		});

		it("Should revert when non-owner tries to update royalties", async function () {
			await expect(cryptoArtNFT.connect(addr1).updateRoyalties(_owner, 500)).to
				.be.reverted;
		});

		it("Should revert when setting royalty percentage too high", async function () {
			const tooHighPercentage = 10001; // 100.01%
			await expect(
				cryptoArtNFT
					.connect(_owner)
					.updateRoyalties(_owner.address, tooHighPercentage)
			).to.be.revertedWith("Royalty percentage too high");
		});
	});

	describe("Metadata", function () {
		it("Should set base URI", async function () {
			const newBaseURI = "https://ipfs.io/ipfs/";
			await expect(cryptoArtNFT.connect(_owner).setBaseURI(newBaseURI)).to.not
				.be.reverted;

			// Mint a token to test the new base URI
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			expect(await cryptoArtNFT.tokenURI(_tokenId1)).to.equal(
				newBaseURI + redeemableTrueURI
			);
		});

		it("Should revert when non-owner tries to set base URI", async function () {
			const newBaseURI = "https://example.com/";
			await expect(cryptoArtNFT.connect(addr1).setBaseURI(newBaseURI)).to.be
				.reverted;
		});

		it("Should revert when non-owner tries to trigger metadata update", async function () {
			const tokenId = 1;
			await expect(cryptoArtNFT.connect(addr1).triggerMetadataUpdate(tokenId))
				.to.be.reverted;
		});

		it("Should update metadata", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			const tokenId = id;
			const newURI = redeemableTrueURI;
			await expect(cryptoArtNFT.connect(_owner).updateMetadata(tokenId, newURI))
				.to.emit(cryptoArtNFT, "MetadataUpdate")
				.withArgs(tokenId);

			expect(await cryptoArtNFT.tokenURI(tokenId)).to.equal(newURI);
		});

		it("Should trigger metadata update", async function () {
			const tokenId = 1;
			await expect(cryptoArtNFT.connect(_owner).triggerMetadataUpdate(tokenId))
				.to.emit(cryptoArtNFT, "MetadataUpdate")
				.withArgs(tokenId);
		});

		it("Should revert when non-owner tries to update metadata", async function () {
			await expect(cryptoArtNFT.connect(addr1).updateMetadata(1, "newURI")).to
				.be.reverted;
		});
	});

	describe("Authority Signer", function () {
		it("Should update authority signer", async function () {
			const newSigner = addr1.address;
			await expect(
				cryptoArtNFT.connect(_owner).updateAuthoritySigner(newSigner)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.currentAuthoritySigner()).to.equal(newSigner);
		});

		it("Should revert when non-owner tries to update authority signer", async function () {
			(
				await expect(
					cryptoArtNFT.connect(addr1).updateAuthoritySigner(addr2.address)
				)
			).to.be.revertedWith("Ownable: caller is not the owner");
		});
	});

	describe("Total Supply", function () {
		it("Should return correct total supply", async function () {
			const initialSupply = await cryptoArtNFT.totalSupply();

			// Mint a token
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			await cryptoArtNFT.connect(_owner).setTotalSupply(1n);

			const newSupply = await cryptoArtNFT.totalSupply();
			expect(newSupply).to.equal(initialSupply + 1n);
		});

		it("Should set total supply", async function () {
			const newSupply = 1000n;
			await expect(cryptoArtNFT.connect(_owner).setTotalSupply(newSupply)).to
				.not.be.reverted;

			expect(await cryptoArtNFT.totalSupply()).to.equal(newSupply);
		});

		it("Should revert when non-owner tries to set total supply", async function () {
			(
				await expect(cryptoArtNFT.connect(addr1).setTotalSupply(1000))
			).to.be.revertedWith("Ownable: caller is not the owner");
		});
	});

	describe("mintWithBurns", function () {
		it("Should revert when trying to mint an already minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// First mint
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			// Attempt to mint the same token with burns
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithBurns(
						id,
						[],
						MintTypesEnum.OpenMint,
						_priceInWei,
						0,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{ value: _priceInWei }
					)
			).to.be.revertedWith("Token already minted.");
		});
	});

	describe("mintWithTrade", function () {
		it("Should revert when trying to mint an already minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// First mint
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			// Attempt to mint the same token with trade
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithTrade(
						id,
						[_tokenId2],
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{ value: _priceInWei }
					)
			).to.be.revertedWith("Token already minted.");
		});

		it("Should revert when no tokens are provided for trade", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithTrade(
						id,
						[],
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{ value: _priceInWei }
					)
			).to.be.revertedWith("No tokens provided for trade");
		});

		it("Should revert when sender doesn't own the tokens to trade", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			const { id: id2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr2.address,
				_tokenId2,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Mint a token for addr2
			await cryptoArtNFT
				.connect(addr2)
				.mint(
					id2,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature2,
					{ value: _priceInWei }
				);

			// Attempt to trade with a token owned by addr2
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithTrade(
						id,
						[id2],
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{ value: _priceInWei }
					)
			).to.be.revertedWith("Sender must own the tokens to trade");
		});
	});

	describe("Burning", function () {
		it("Should allow the token owner to burn a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(1);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});

		it("Emits a Burned event when burning a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await expect(cryptoArtNFT.connect(addr1).burn(1))
				.to.emit(cryptoArtNFT, "Burned")
				.withArgs(1);
		});

		it("Should not allow non-token owner to burn a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await expect(cryptoArtNFT.connect(addr2).burn(id)).to.be.revertedWith(
				"Caller is not owner nor approved"
			);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should update burnCount after burning a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(1);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);
		});

		it("Should update burnCount after batch burning tokens", async function () {
			const { id: idToken1, signature: signatureToken1 } =
				await getSignatureForMint(cryptoArtNFT, addr1.address, _tokenId1);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					idToken1,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signatureToken1,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			const { id: idToken2, signature: signatureToken2 } =
				await getSignatureForMint(cryptoArtNFT, addr1.address, _tokenId2);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					idToken2,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signatureToken2,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(2);

			// Burn the token
			await cryptoArtNFT.connect(addr1).batchBurn([1, 2]);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(2);
		});

		it("Should allow minting with burns and decrease burnCount", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(id);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);

			const { id: idToken2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId2,
				MintTypesEnum.Burn,
				_priceInWei,
				1
			);
			await cryptoArtNFT
				.connect(addr1)
				.mintWithBurns(
					idToken2,
					[id],
					MintTypesEnum.Burn,
					_priceInWei,
					1,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature2,
					{
						value: ethers.parseEther("0.1"),
					}
				);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should allow burn and mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			// Burn the token
			const { id: idToken2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId2,
				MintTypesEnum.Burn,
				_priceInWei,
				1
			);
			await cryptoArtNFT
				.connect(addr1)
				.burnAndMint(
					[id],
					idToken2,
					MintTypesEnum.Burn,
					_priceInWei,
					[id].length,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature2,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should revert minting with burns when burnCount is less than burns used", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Burn,
				_priceInWei
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.Burn,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(id);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);

			const { id: idToken2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithBurns(
						idToken2,
						[id],
						MintTypesEnum.Burn,
						_priceInWei,
						2,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature2,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not enough burns available.");
		});

		it("Should allow approved address to burn token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			await cryptoArtNFT.connect(addr1).setApprovalForAll(addr2.address, true);

			await expect(cryptoArtNFT.connect(addr2).burn(id))
				.to.emit(cryptoArtNFT, "Burned")
				.withArgs(id);
		});
	});

	describe("MintWithTrade", function () {
		it("Should trade two tokens and mint a new one", async function () {
			// Mint initial tokens with signatures
			const { signature: sig1 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					_tokenId1,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					sig1,
					{
						value: _priceInWei,
					}
				);

			const { signature: sig2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId2,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					_tokenId2,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					sig2,
					{
						value: _priceInWei,
					}
				);

			// Ensure initial balances
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(2);

			// Get signature for trading the minted tokens for a new token
			const _newTokenId = 3;
			const { signature: tradeSignature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_newTokenId,
				MintTypesEnum.OpenMint,
				ethers.parseEther("0"),
				2 // Now indicating number of tokens being traded
			);

			// Perform the trade and mint new token
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mintWithTrade(
						_newTokenId,
						[_tokenId1, _tokenId2],
						MintTypesEnum.OpenMint,
						ethers.parseEther("0"),
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						tradeSignature
					)
			)
				.to.emit(cryptoArtNFT, "MintedByTrading")
				.withArgs(_newTokenId, [_tokenId1, _tokenId2]);

			// Assert final balances
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1); // Now should have only the new token
		});
	});

	describe("Claimable", function () {
		it("Should allow user to claim a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable
			);

			await cryptoArtNFT
				.connect(addr1)
				.claimable(
					id,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should allow user to claim a token by paying", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable,
				_priceInWei
			);

			await cryptoArtNFT
				.connect(addr1)
				.claimable(
					id,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Emits a Claimed event when claiming a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.claimable(
						id,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature
					)
			)
				.to.emit(cryptoArtNFT, "Claimed")
				.withArgs(id);
		});

		it("Should not allow user to claim an unclaimable token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.claimable(
						id,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature
					)
			).to.be.revertedWith("Not authorized to mint");
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});

		it("Should revert when trying to claim an already minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable
			);

			// First claim (should succeed)
			await cryptoArtNFT
				.connect(addr1)
				.claimable(
					id,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature
				);

			// Second claim (should fail)
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.claimable(
						id,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature
					)
			).to.be.revertedWith("Token already minted or claimed.");
		});
	});

	describe("Withdraw", function () {
		let mockReceiver: MockReceiver;

		beforeEach(async function () {
			// Deploy the MockReceiver contract
			const MockReceiverFactory = await ethers.getContractFactory(
				"MockReceiver"
			);
			mockReceiver = await MockReceiverFactory.deploy();
			// await mockReceiver.deployed();
		});

		it("withdraw should transfer all contract balance to the owner", async function () {
			// Mint to transfer ETH to contract
			const amount = ethers.parseEther("1");
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				amount,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					amount,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: amount,
					}
				);

			// Check current balance
			const initialOwnerBalance = await ethers.provider.getBalance(
				_owner.address
			);

			const tx = await cryptoArtNFT.connect(_owner).withdraw();
			await tx.wait();

			const finalOwnerBalance = await ethers.provider.getBalance(
				_owner.address
			);
			expect(BigInt(finalOwnerBalance)).to.be.greaterThanOrEqual(
				initialOwnerBalance
			);
		});

		it("withdraw should transfer all contract balance to the new owner", async function () {
			await cryptoArtNFT.connect(_owner).updateOwner(addr1.address);
			expect(await cryptoArtNFT.owner()).to.equal(addr1.address);

			// Mint to transfer ETH to contract
			const amount = ethers.parseEther("1");
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				amount,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					amount,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: amount,
					}
				);

			// Check current balance
			const initialOwnerBalance = await ethers.provider.getBalance(
				_owner.address
			);

			const tx = await cryptoArtNFT.connect(addr1).withdraw();
			await tx.wait();

			const finalOwnerBalance = await ethers.provider.getBalance(
				_owner.address
			);
			expect(BigInt(finalOwnerBalance)).to.be.greaterThanOrEqual(
				initialOwnerBalance
			);
		});

		it("withdraw should revert if called by non-owner", async function () {
			await expect(cryptoArtNFT.connect(addr2).withdraw()).to.be.reverted;
		});

		it("withdraw should revert if contract has no balance", async function () {
			await expect(cryptoArtNFT.connect(_owner).withdraw()).to.be.revertedWith(
				"No funds available for withdrawal"
			);
		});

		it("Should revert when transfer fails", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			// Set the owner to the mock receiver
			const mockReceiverAddress = await mockReceiver.getAddress();
			await cryptoArtNFT.connect(_owner).updateOwner(mockReceiverAddress);

			// Add funds to the MockReceiver
			await ethers.provider.send("hardhat_setBalance", [
				mockReceiverAddress,
				ethers.toBeHex(ethers.parseEther("10.0")),
			]);

			// Impersonate the MockReceiver
			await ethers.provider.send("hardhat_impersonateAccount", [
				mockReceiverAddress,
			]);
			const impersonatedSigner = await ethers.provider.getSigner(
				mockReceiverAddress
			);

			// Attempt to withdraw using the impersonated MockReceiver as the new owner
			await expect(
				cryptoArtNFT.connect(impersonatedSigner).withdraw()
			).to.be.revertedWith("Transfer failed.");

			// Stop impersonating the account
			await ethers.provider.send("hardhat_stopImpersonatingAccount", [
				mockReceiverAddress,
			]);
		});
	});

	describe("ERC-7160", function () {
		it("Should return the correct token URI", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableTrueURI);
		});

		it("Should return 2 token URIs on mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableTrueURI);

			const tokenUris = (await cryptoArtNFT.tokenURIs(id))[1];
			expect(tokenUris.length).to.equal(2);
		});

		it("Should return 2 token URIs on mint by trading", async function () {
			// Mint initial tokens with signatures
			const { signature: sig1 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					_tokenId1,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					sig1,
					{
						value: _priceInWei,
					}
				);

			const { signature: sig2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId2,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					_tokenId2,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					sig2,
					{
						value: _priceInWei,
					}
				);

			// Ensure initial balances
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(2);

			// Get signature for trading the minted tokens for a new token
			const _newTokenId = 3;
			const { signature: tradeSignature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_newTokenId,
				MintTypesEnum.OpenMint,
				ethers.parseEther("0"),
				2 // Now indicating number of tokens being traded
			);

			await cryptoArtNFT
				.connect(addr1)
				.mintWithTrade(
					_newTokenId,
					[_tokenId1, _tokenId2],
					MintTypesEnum.OpenMint,
					ethers.parseEther("0"),
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					tradeSignature
				);

			const tokenUris = (await cryptoArtNFT.tokenURIs(_newTokenId))[1];
			expect(tokenUris.length).to.equal(2);
		});

		it("Should return 2 token URIs on mint by burning", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(id);

			const { id: idToken2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId2,
				MintTypesEnum.Burn,
				_priceInWei,
				1
			);
			await cryptoArtNFT
				.connect(addr1)
				.mintWithBurns(
					idToken2,
					[id],
					MintTypesEnum.Burn,
					_priceInWei,
					1,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature2,
					{
						value: ethers.parseEther("0.1"),
					}
				);

			const tokenUris = (await cryptoArtNFT.tokenURIs(idToken2))[1];
			expect(tokenUris.length).to.equal(2);
		});

		it("Should return 2 token URIs on claim mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.Claimable
			);

			await cryptoArtNFT
				.connect(addr1)
				.claimable(
					id,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature
				);

			const tokenUris = (await cryptoArtNFT.tokenURIs(id))[1];
			expect(tokenUris.length).to.equal(2);
		});

		it("Should unpair a token if NFT Owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const { id: redeemableId, signature: redeemableSignature } =
				await getSignatureForUnpair(cryptoArtNFT, addr1.address, _tokenId1);
			expect(
				await cryptoArtNFT
					.connect(addr1)
					.pinRedeemableTrueTokenUri(redeemableId, redeemableSignature)
			)
				.to.emit(cryptoArtNFT, "TokenUriPinned")
				.withArgs(id, 0)
				.and.to.emit(cryptoArtNFT, "MetadataUpdate")
				.withArgs(id);
			expect(await cryptoArtNFT.tokenURI(redeemableId)).to.equal(
				redeemableTrueURI
			);
		});

		it("Should not unpair a token if not NFT Owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const { id: redeemableId, signature: redeemableSignature } =
				await getSignatureForUnpair(cryptoArtNFT, addr1.address, _tokenId1);

			await expect(
				cryptoArtNFT
					.connect(addr2)
					.pinRedeemableTrueTokenUri(redeemableId, redeemableSignature)
			).to.revertedWith("Unauthorized");

			expect(await cryptoArtNFT.tokenURI(redeemableId)).to.equal(
				redeemableTrueURI
			);
		});

		it("Should not unpair a token if invalid voucher", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const { id: redeemableId, signature: redeemableSignature } =
				await getSignatureForUnpair(cryptoArtNFT, addr1.address, _tokenId1);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.pinRedeemableTrueTokenUri(_tokenId2, redeemableSignature)
			).to.reverted;

			expect(await cryptoArtNFT.tokenURI(redeemableId)).to.equal(
				redeemableTrueURI
			);
		});

		it("Should set redeemable false on token as contract owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			expect(await cryptoArtNFT.connect(_owner).pinTokenURI(id, 1))
				.to.emit(cryptoArtNFT, "TokenUriPinned")
				.withArgs(id, 1)
				.and.to.emit(cryptoArtNFT, "MetadataUpdate")
				.withArgs(id);

			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableFalseURI);
		});

		it("Should not set redeemable false on token as 3rd account", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			await expect(cryptoArtNFT.connect(addr2).pinTokenURI(id, 1)).to.reverted;

			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableTrueURI);
		});

		it("Should emit metadata update event", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const { id: redeemableId, signature: redeemableSignature } =
				await getSignatureForUnpair(cryptoArtNFT, addr1.address, _tokenId1);

			expect(
				await cryptoArtNFT
					.connect(addr1)
					.pinRedeemableTrueTokenUri(redeemableId, redeemableSignature)
			)
				.to.emit(cryptoArtNFT, "MetadataUpdate")
				.withArgs(id);
		});

		it("Should emit token uri pinned event", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			const { id: redeemableId, signature: redeemableSignature } =
				await getSignatureForUnpair(cryptoArtNFT, addr1.address, _tokenId1);

			expect(
				await cryptoArtNFT
					.connect(addr1)
					.pinRedeemableTrueTokenUri(redeemableId, redeemableSignature)
			)
				.to.emit(cryptoArtNFT, "TokenUriPinned")
				.withArgs(id);
		});
	});

	describe("Story", function () {
		it("Should add Story to minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			expect(await cryptoArtNFT.connect(addr1).addStory(id, "", story))
				.to.emit(cryptoArtNFT, "Story")
				.withArgs(id, addr1.address, addr1.address, story);
		});

		it("Should revert addStory if wallet is not NFT owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await expect(
				cryptoArtNFT.connect(addr2).addStory(id, "", story)
			).to.be.revertedWith("Caller is not the owner of the token");
		});

		it("Should revert addStory if token is not minted", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await expect(
				cryptoArtNFT.connect(addr1).addStory(_tokenId2, "", story)
			).to.be.revertedWith("Token does not exist");
		});

		it("Should toggle story visibility if token owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await cryptoArtNFT.connect(addr1).addStory(id, "", story);

			expect(
				await cryptoArtNFT
					.connect(addr1)
					.toggleStoryVisibility(id, "123", false)
			)
				.to.emit(cryptoArtNFT, "ToggleStoryVisibility")
				.withArgs(id, "123", false);
		});

		it("Should toggle story visibility if contract owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await cryptoArtNFT.connect(addr1).addStory(id, "", story);

			expect(
				await cryptoArtNFT
					.connect(_owner)
					.toggleStoryVisibility(id, "123", false)
			)
				.to.emit(cryptoArtNFT, "ToggleStoryVisibility")
				.withArgs(id, "123", false);
		});

		it("Should revert toggle story visibility if not token owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await cryptoArtNFT.connect(addr1).addStory(id, "", story);

			await expect(
				cryptoArtNFT.connect(addr2).toggleStoryVisibility(id, "123", false)
			).to.be.revertedWith("Caller is not the owner of the token");
		});

		it("Should revert toggle story visibility if token not exists", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a story";
			await cryptoArtNFT.connect(addr1).addStory(id, "", story);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.toggleStoryVisibility(_tokenId2, "123", false)
			).to.be.revertedWith("Token does not exist");
		});
	});

	describe("Creator Story", function () {
		it("Should add Creator Story to minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a creator story";
			expect(await cryptoArtNFT.connect(addr1).addCreatorStory(id, "", story))
				.to.emit(cryptoArtNFT, "CreatorStory")
				.withArgs(id, addr1.address, story);
		});

		it("Should revert addCreatorStory if caller is not the token owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			const story = "This is a creator story";
			await expect(cryptoArtNFT.connect(addr2).addCreatorStory(id, "", story))
				.to.be.reverted;
		});
	});

	describe("Token URI Pinning", function () {
		it("Should return correct hasPinnedTokenURI status", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);
			expect(await cryptoArtNFT.hasPinnedTokenURI(id)).to.be.false;

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);
			expect(await cryptoArtNFT.hasPinnedTokenURI(id)).to.be.true;
		});

		it("Should unpin token URI", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			expect(await cryptoArtNFT.hasPinnedTokenURI(id)).to.be.true;
			expect(await cryptoArtNFT.connect(_owner).unpinTokenURI(id))
				.to.emit(cryptoArtNFT, "TokenUriUnpinned")
				.withArgs(id);
			expect(await cryptoArtNFT.hasPinnedTokenURI(id)).to.be.true;
		});

		it("Should revert unpinTokenURI if caller is not the contract owner", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			await expect(cryptoArtNFT.connect(addr1).unpinTokenURI(id)).to.not.be
				.reverted;
		});
	});

	describe("Authorized Mint Validation", function () {
		it("Should validate authorized mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;
		});

		it("Should revert on unauthorized mint", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint
			);

			await expect(
				cryptoArtNFT
					.connect(addr2)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});
	});

	describe("Collection Story", function () {
		it("Should add Collection Story", async function () {
			const story = "This is a collection story";
			expect(await cryptoArtNFT.connect(_owner).addCollectionStory("", story))
				.to.emit(cryptoArtNFT, "CollectionStory")
				.withArgs(_owner.address, story);
		});

		it("Should execute addCollectionStory empty", async function () {
			const story = "This is a collection story";
			await expect(cryptoArtNFT.connect(addr1).addCollectionStory("", story)).to
				.not.be.reverted;
		});
	});

	describe("Initialization", function () {
		it("Should initialize with non-zero address", async function () {
			const CryptoArtNFTFactory = await ethers.getContractFactory(
				"CryptoartNFT"
			);
			const proxyContract = await upgrades.deployProxy(
				CryptoArtNFTFactory,
				[_owner.address, _signerAuthorityWallet.address],
				{
					initializer: "initialize",
				}
			);
			const nft = proxyContract as unknown as CryptoArtNFT;

			expect(await nft.owner()).to.equal(_owner.address);
			expect(await nft.currentAuthoritySigner()).to.equal(
				_signerAuthorityWallet.address
			);
		});

		it("Should not initialize with zero address", async function () {
			const CryptoArtNFTFactory = await ethers.getContractFactory(
				"CryptoartNFT"
			);

			await expect(
				upgrades.deployProxy(
					CryptoArtNFTFactory,
					[ethers.ZeroAddress, _signerAuthorityWallet.address],
					{
						initializer: "initialize",
					}
				)
			).to.be.reverted;
		});
	});

	describe("Authorized Minting", function () {
		it("Should allow minting with valid signature", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.ownerOf(id)).to.equal(addr1.address);
		});

		it("Should revert minting with invalid signature", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Use a different signer to generate an invalid signature
			const invalidSignature = await fakeSigner.signMessage(
				ethers.getBytes(signature)
			);

			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						invalidSignature,
						{
							value: _priceInWei,
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Should revert minting with mismatched parameters", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// Try to mint with a different tokenId
			await expect(
				cryptoArtNFT.connect(addr1).mint(
					_tokenId2, // Different tokenId
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Should revert minting with expired nonce", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// First mint should succeed
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				);

			// Try to mint again with the same signature (nonce should be expired)
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.mint(
						_tokenId2,
						MintTypesEnum.OpenMint,
						_priceInWei,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{
							value: _priceInWei,
						}
					)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Should revert minting with incorrect mint type", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			await expect(
				cryptoArtNFT.connect(addr1).mint(
					id,
					MintTypesEnum.Whitelist, // Different mint type
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: _priceInWei,
					}
				)
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Should revert minting with incorrect token price", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			const incorrectPrice = _priceInWei * 2n;

			await expect(
				cryptoArtNFT.connect(addr1).mint(
					id,
					MintTypesEnum.OpenMint,
					incorrectPrice, // Different price
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{
						value: incorrectPrice,
					}
				)
			).to.be.revertedWith("Not authorized to mint");
		});
	});

	describe("burnAndMint", function () {
		it("Should revert when trying to mint an already minted token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				MintTypesEnum.OpenMint,
				_priceInWei,
				0
			);

			// First mint
			await cryptoArtNFT
				.connect(addr1)
				.mint(
					id,
					MintTypesEnum.OpenMint,
					_priceInWei,
					redeemableTrueURI,
					redeemableFalseURI,
					0,
					signature,
					{ value: _priceInWei }
				);

			// Attempt to burn and mint the same token
			await expect(
				cryptoArtNFT
					.connect(addr1)
					.burnAndMint(
						[_tokenId2],
						id,
						MintTypesEnum.OpenMint,
						_priceInWei,
						1,
						redeemableTrueURI,
						redeemableFalseURI,
						0,
						signature,
						{ value: _priceInWei }
					)
			).to.be.revertedWith("Token already minted.");
		});
	});

	describe("updateOwner", function () {
		it("Should revert when non-owner tries to update owner", async function () {
			await expect(cryptoArtNFT.connect(addr1).updateOwner(addr2.address)).to.be
				.reverted;
		});
	});
});
