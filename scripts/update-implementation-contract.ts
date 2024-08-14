import { ethers, upgrades } from "hardhat";

async function main(): Promise<void> {
	// current TransparentUpgradeableProxy address. Not the proxy itself
	const currentProxy = process.env.CONTRACT as string;
	const CryptoArtNFT = await ethers.getContractFactory("CryptoartNFT");

	const cryptoArtNFT = await upgrades.upgradeProxy(
		currentProxy,
		CryptoArtNFT
		//   , {
		// 	txOverrides: {
		// 		gasPrice: ethers.parseUnits("7", "gwei"),
		// 	},
		// }
	);

	console.log("CryptoArtNFT deployed to:", cryptoArtNFT.target);
	console.log("Proxy address:", currentProxy);
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
