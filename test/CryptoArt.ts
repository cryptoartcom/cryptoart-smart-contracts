import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import MerkleTree from "merkletreejs";
import { CryptoArtNFT } from "../typechain-types";
import { AbiCoder } from "ethers";
import { keccak256 } from "ethereumjs-util";

const _tokenId1 = 1;
const _tokenId2 = 2;
const _tokenId3 = 3;
const _nullAddress = "0x0000000000000000000000000000000000000000";
const _owner = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);
const _signerAuthorityWallet = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);

const getSignatureForMint = async (
	contractAddress: CryptoArtNFT,
	minter: any,
	id: any,
	isClaimable: boolean = false,
	signer: HardhatEthersSigner | null = null
) => {
	const signerAuthority = signer ?? _signerAuthorityWallet;
	const nonce = await contractAddress.nonces(minter);
	const chainId = network.config.chainId;
	const verifyingContract = contractAddress.target;

	const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
		["address", "uint256", "uint256", "uint256", "bool", "address"],
		[minter, id, nonce, chainId, isClaimable, verifyingContract]
	);

	const digest = ethers.getBytes(ethers.keccak256(encodedData));

	const signature = await signerAuthority.signMessage(digest);

	return {
		minter,
		id,
		signature,
	};
};

const getSignatureForBurnableMint = async (
	contractAddress: CryptoArtNFT,
	minter: any,
	id: any,
	burnsToUse: number,
	signer: HardhatEthersSigner | null = null
) => {
	const signerAuthority = signer ?? _signerAuthorityWallet;
	const nonce = await contractAddress.nonces(minter);
	const chainId = network.config.chainId;
	const verifyingContract = contractAddress.target;

	const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
		["address", "uint256", "uint256", "uint256", "uint256", "address"],
		[minter, id, nonce, chainId, burnsToUse, verifyingContract]
	);

	const digest = ethers.getBytes(ethers.keccak256(encodedData));

	const signature = await signerAuthority.signMessage(digest);

	return {
		minter,
		id,
		signature,
	};
};

describe("CryptoArtNFT", function () {
	let cryptoArtNFT: CryptoArtNFT;
	let addr1: HardhatEthersSigner;
	let addr2: HardhatEthersSigner;
	let fakeSigner: HardhatEthersSigner;

	beforeEach(async function () {
		[addr1, addr2, fakeSigner] = await ethers.getSigners();
		const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoArtNFT");
		const proxyContract = await upgrades.deployProxy(CryptoArtNFTFactory, {
			initializer: "initialize",
			constructorArgs: [_owner.address, _signerAuthorityWallet.address],
		});
		cryptoArtNFT = proxyContract as unknown as CryptoArtNFT;
	});

	describe("Deployment", function () {
		it("Should set the right Owner & Authority Signer", async function () {
			expect(await cryptoArtNFT.owner()).to.equal(_owner.address);
			expect(await cryptoArtNFT.currentAuthoritySigner()).to.equals(
				_signerAuthorityWallet.address
			);
		});
	});

	// describe("Owner Privileges", function () {
	// 	it("should allow the owner to update the merkle root", async function () {
	// 		const newMerkleRoot =
	// 			"0x1234567890123456789012345678901234567890123456789012345678901234";
	// 		await cryptoArtNFT.connect(owner).updateMerkleRoot(newMerkleRoot);
	// 		expect(await cryptoArtNFT.merkleRoot()).to.equal(newMerkleRoot);
	// 	});
	// });

	// describe("Non-owner Privileges", function () {
	// 	it("should not allow non-owners to update the merkle root", async function () {
	// 		const newMerkleRoot =
	// 			"0x1234567890123456789012345678901234567890123456789012345678901234";
	// 		await expect(cryptoArtNFT.connect(addr1).updateMerkleRoot(newMerkleRoot))
	// 			.to.be.reverted;
	// 	});

	// 	// ... more test cases for non-owner functions ...
	// });

	describe("Minting", function () {
		it("Mint only if valid signature: valid", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// Allow addr1 to mint
			await expect(
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint only if valid signature: invalid signer", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				false,
				fakeSigner
			);

			await expect(
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Mint only if valid signature: invalid parameters mismatch", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			// mismatch token
			await expect(
				cryptoArtNFT.connect(addr1).mint(_tokenId2, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.be.revertedWith("Not authorized to mint");

			// mismatch wallet
			await expect(
				cryptoArtNFT.connect(addr2).mint(_tokenId1, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.be.revertedWith("Not authorized to mint");

			// mismatch token and wallet
			await expect(
				cryptoArtNFT.connect(addr2).mint(_tokenId2, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.be.revertedWith("Not authorized to mint");
		});

		it("Mint only if valid signature: invalid signature (signature for other user)", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				false,
				fakeSigner
			);

			await expect(
				cryptoArtNFT.connect(addr2).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;
			await expect(
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;
			await expect(
				cryptoArtNFT.connect(addr1).mint(_tokenId2, signature, {
					value: ethers.parseEther("0.1"),
				})
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;
			await expect(cryptoArtNFT.connect(addr1).burn(id));
			await expect(
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.01"),
				})
			).to.not.be.reverted;

			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Mint after burning using a new signature voucher", async function () {
			const { signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await expect(
				cryptoArtNFT.connect(addr1).mint(_tokenId1, signature, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			await cryptoArtNFT.connect(addr1).burn(_tokenId1);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);

			const { signature: newSignaturePostBurn } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await expect(
				cryptoArtNFT.connect(addr1).mint(_tokenId1, newSignaturePostBurn, {
					value: ethers.parseEther("0.1"),
				})
			).to.not.be.reverted;
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
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
				cryptoArtNFT.connect(addr1).mint(id, signature, {
					value: ethers.parseEther("0.1"),
				})
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

			await cryptoArtNFT.connect(addr1).mint(id, signature, {
				value: ethers.parseEther("0.1"),
			});
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(1);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});

		it("Should not allow non-token owner to burn a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);

			await cryptoArtNFT.connect(addr1).mint(id, signature, {
				value: ethers.parseEther("0.1"),
			});
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

			await cryptoArtNFT.connect(addr1).mint(id, signature, {
				value: ethers.parseEther("0.1"),
			});
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(1);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);
		});

		it("Should update burnCount after batch burning tokens", async function () {
			const { id: idToken1, signature: signatureToken1 } =
				await getSignatureForMint(cryptoArtNFT, addr1.address, _tokenId1);
			await cryptoArtNFT.connect(addr1).mint(idToken1, signatureToken1, {
				value: ethers.parseEther("0.1"),
			});
			const { id: idToken2, signature: signatureToken2 } =
				await getSignatureForMint(cryptoArtNFT, addr1.address, _tokenId2);
			await cryptoArtNFT.connect(addr1).mint(idToken2, signatureToken2, {
				value: ethers.parseEther("0.1"),
			});

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
			await cryptoArtNFT.connect(addr1).mint(id, signature, {
				value: ethers.parseEther("0.1"),
			});

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(id);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);

			const { id: idToken2, signature: signature2 } =
				await getSignatureForBurnableMint(
					cryptoArtNFT,
					addr1.address,
					_tokenId1,
					1
				);
			await cryptoArtNFT.connect(addr1).mintWithBurns(idToken2, 1, signature2, {
				value: ethers.parseEther("0.1"),
			});
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(0);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should revert minting with burns when burnCount is less than burns used", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await cryptoArtNFT.connect(addr1).mint(id, signature, {
				value: ethers.parseEther("0.1"),
			});

			// Burn the token
			await cryptoArtNFT.connect(addr1).burn(id);
			expect(await cryptoArtNFT.burnCount(addr1.address)).to.equal(1);

			const { id: idToken2, signature: signature2 } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1
			);
			await expect(
				cryptoArtNFT.connect(addr1).mintWithBurns(idToken2, 2, signature2, {
					value: ethers.parseEther("0.1"),
				})
			).to.be.revertedWith("Not enough burns available.");
		});
	});

	describe("Claimable", function () {
		it("Should allow user to claim a token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				true
			);

			await cryptoArtNFT.connect(addr1).claimable(id, signature);
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(1);
		});

		it("Should not allow user to claim an unclaimable token", async function () {
			const { id, signature } = await getSignatureForMint(
				cryptoArtNFT,
				addr1.address,
				_tokenId1,
				false
			);

			await expect(
				cryptoArtNFT.connect(addr1).claimable(id, signature)
			).to.be.revertedWith("Not authorized to mint");
			expect(await cryptoArtNFT.balanceOf(addr1.address)).to.equal(0);
		});
	});
});
