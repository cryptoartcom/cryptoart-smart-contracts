import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { CryptoartNFT as CryptoArtNFT } from "../typechain-types";

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
	signer: HardhatEthersSigner | null = null
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
						signature,
						{
							value: _priceInWei,
						}
					)
			)
				.to.emit(cryptoArtNFT, "Minted")
				.withArgs(id);
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
						signature,
						{
							value: ethers.parseEther("0.01"),
						}
					)
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		// it("Mint after burning using a new signature voucher", async function () {
		// 	const { signature } = await getSignatureForMint(
		// 		cryptoArtNFT,
		// 		addr1.address,
		// 		_tokenId1
		// 	);

		// 	await expect(
		// 		cryptoArtNFT
		// 			.connect(addr1)
		// 			.mint(
		// 				_tokenId1,
		// 				MintTypesEnum.OpenMint,
		// 				_priceInWei,
		// 				redeemableTrueURI,
		// 				redeemableFalseURI,
		// 				signature,
		// 				{
		// 					value: ethers.parseEther("0.1"),
		// 				}
		// 			)
		// 	).to.not.be.reverted;
		// 	expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

		// 	await cryptoArtNFT.connect(addr1).burn(_tokenId1);
		// 	expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);

		// 	const { signature: newSignaturePostBurn } = await getSignatureForMint(
		// 		cryptoArtNFT,
		// 		addr1.address,
		// 		_tokenId1
		// 	);

		// 	await expect(
		// 		cryptoArtNFT
		// 			.connect(addr1)
		// 			.mint(
		// 				_tokenId1,
		// 				MintTypesEnum.OpenMint,
		// 				_priceInWei,
		// 				redeemableTrueURI,
		// 				redeemableFalseURI,
		// 				newSignaturePostBurn,
		// 				{
		// 					value: ethers.parseEther("0.1"),
		// 				}
		// 			)
		// 	).to.not.be.reverted;
		// 	expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		// });
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
				_tokenId1,
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
						signature2,
						{
							value: ethers.parseEther("0.1"),
						}
					)
			).to.be.revertedWith("Not enough burns available.");
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
					signature
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
						signature
					)
			).to.be.revertedWith("Not authorized to mint");
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});
	});

	describe("Withdraw", function () {
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
					signature,
					{
						value: _priceInWei,
					}
				);

			expect(await cryptoArtNFT.tokenURI(id)).to.equal(redeemableTrueURI);

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
});
