import { ethers, upgrades } from "hardhat";

async function main(): Promise<void> {
	const CryptoArtNFT = await ethers.getContractFactory("CryptoArtNFT");

	const cryptoArtNFT = await upgrades.deployProxy(CryptoArtNFT, {
		initializer: "initialize",
	});

	console.log("CryptoArtNFT deployed to:", cryptoArtNFT.target);
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
