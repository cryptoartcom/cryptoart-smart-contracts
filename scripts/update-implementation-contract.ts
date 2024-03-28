import { ethers, upgrades } from "hardhat";

async function main(): Promise<void> {
	const currentProxy = "0xb7f83160D8b7106516c18b533aaeFe4458E11Cf4";
	const CryptoArtNFT = await ethers.getContractFactory("CryptoArtNFT");

	const cryptoArtNFT = await upgrades.upgradeProxy(currentProxy, CryptoArtNFT);

	console.log("CryptoArtNFT deployed to:", cryptoArtNFT.target);
	console.log("Proxy address:", currentProxy);
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
