import { ethers } from "hardhat";

async function main() {
	const CryptoArtNFT = await ethers.getContractFactory("CryptoArtNFT");
	const nft = await CryptoArtNFT.deploy();

	await nft.deployed();

	console.log("CryptoArtNFT deployed to:", nft.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
	console.error(error);
	process.exitCode = 1;
});
