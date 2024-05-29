import { ethers, upgrades } from "hardhat";

async function main(): Promise<void> {
	// current TransparentUpgradeableProxy address. Not the proxy itself
	const currentProxy = "0xB34c2483d7EFEa9C6F7eacf9084d9B3Ef56AbA34";
	// const currentProxy = "0xF3AB7991ce6Bccb53331fa9CB9aA6599699774F5";
	const CryptoArtNFT = await ethers.getContractFactory("CryptoartNFT");

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
