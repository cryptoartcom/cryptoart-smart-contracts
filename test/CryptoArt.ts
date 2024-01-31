import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import MerkleTree from "merkletreejs";
import { CryptoArtNFT } from "../typechain-types";
import { AbiCoder } from "ethers";
import SHA3 from "crypto-js/sha3";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import { keccak256 } from "ethereumjs-util";

describe("CryptoArtNFT", function () {
	let cryptoArtNFT: CryptoArtNFT;
	let owner: HardhatEthersSigner;
	let addr1: HardhatEthersSigner;
	let addr2: HardhatEthersSigner;

	let mintTokens: any[];
	let bufDistributeAmount: Buffer[] | Uint8Array[];
	let tree: MerkleTree;

	const coder = AbiCoder.defaultAbiCoder();

	beforeEach(async function () {
		[owner, addr1, addr2] = await ethers.getSigners();
		const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoArtNFT");
		const proxyContract = await upgrades.deployProxy(CryptoArtNFTFactory, {
			initializer: "initialize",
		});
		cryptoArtNFT = proxyContract as unknown as CryptoArtNFT;

		mintTokens = [
			{ index: 0, account: ethers.getAddress(owner.address), amount: 1 },
			{ index: 1, account: ethers.getAddress(addr1.address), amount: 1 },
			{ index: 2, account: ethers.getAddress(addr2.address), amount: 1 },
		];

		bufDistributeAmount = mintTokens.map((el) =>
			Buffer.from(el.amount.toString(16).padStart(64, "0"), "hex")
		);
		const leaves = mintTokens
			.map((el) =>
				keccak256(
					Buffer.from(
						coder
							.encode(["address", "uint256"], [el.account, el.index])
							.slice(2),
						"hex"
					)
				)
			)
			.sort(Buffer.compare);

		tree = new MerkleTree(leaves, keccak256, { sortPairs: true });
	});

	describe("Deployment", function () {
		it("Should set the right owner", async function () {
			expect(await cryptoArtNFT.owner()).to.equal(owner.address);
		});
	});

	describe("Owner Privileges", function () {
		it("should allow the owner to update the merkle root", async function () {
			const newMerkleRoot =
				"0x1234567890123456789012345678901234567890123456789012345678901234";
			await cryptoArtNFT.connect(owner).updateMerkleRoot(newMerkleRoot);
			expect(await cryptoArtNFT.merkleRoot()).to.equal(newMerkleRoot);
		});
	});

	describe("Non-owner Privileges", function () {
		it("should not allow non-owners to update the merkle root", async function () {
			const newMerkleRoot =
				"0x1234567890123456789012345678901234567890123456789012345678901234";
			await expect(cryptoArtNFT.connect(addr1).updateMerkleRoot(newMerkleRoot))
				.to.be.reverted;
		});

		// ... more test cases for non-owner functions ...
	});

	describe("Minting", function () {
		it("Should verify valid merkle proof", async function () {
			const encodedData = coder.encode(
				["address", "uint256"],
				[mintTokens[1].account, mintTokens[1].index]
			);

			const leafHash = SHA3(encodedData).toString();
			const leaf = Buffer.from(leafHash, "hex");
			const leaves = [leaf];
			const tree = new MerkleTree(leaves, SHA3);
			const root = Buffer.from(tree.getRoot().toString("hex"), "hex");

			const proof = tree.getProof(leaf).map((p) => p.data);
			const isValid = tree.verify(proof, leaf, root);

			expect(isValid).to.equal(true);
		});

		it("should allow users to mint with a valid proof", async function () {
			// Encode and create leaf hashes
			const leafHash1 = [mintTokens[1].account, mintTokens[1].index];
			const leaf1 = leafHash1;

			const leafHash2 = [mintTokens[2].account, mintTokens[2].index];
			const leaf2 = leafHash2;

			const leaves = [leaf1, leaf2];

			// Create a new Merkle tree

			const tree = StandardMerkleTree.of(leaves, ["address", "uint256"]);
			const root = tree.root;

			// Generate the proof for leaf1
			let proof: string[] = [];
			for (const [i, v] of tree.entries()) {
				if (v[0] === leafHash1[0]) {
					proof = tree.getProof(i);
				}
			}

			// Update merkle root
			await cryptoArtNFT.connect(owner).updateMerkleRoot(root);

			// Allow addr1 to mint
			await cryptoArtNFT.connect(addr1).mint(1, "meteor", proof, {
				value: ethers.parseEther("0.1"),
			});

			const balance = await cryptoArtNFT.balanceOf(addr1.address);

			expect(balance).to.equal(1);
		});

		it("should not allow users to mint with an invalid proof", async function () {
			const invalidProof = [
				"0x0000000000000000000000000000000000000000000000000000000000000000",
			];
			// An invalid proof prevents minting.
			await expect(
				cryptoArtNFT.connect(addr2).mint(1, "metadataURI", invalidProof, {
					value: ethers.parseEther("0.0001"),
				})
			).to.be.revertedWith("Invalid proof");
		});

		it("should not allow non-whitelisted users to mint", async function () {
			const validProof = tree.getHexProof(
				keccak256(
					Buffer.concat([
						bufDistributeAmount[0],
						Buffer.from(
							mintTokens[0].account.slice(2).padStart(64, "0"),
							"hex"
						),
					])
				)
			);
			// addr2 is not whitelisted, so this transaction will be reverted
			await expect(
				cryptoArtNFT.connect(addr2).mint(1, "metadataURI", validProof, {
					value: ethers.parseEther("0.0001"),
				})
			).to.be.revertedWith("Invalid proof");
		});
	});
});
