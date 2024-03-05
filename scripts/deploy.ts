import { ethers, upgrades } from "hardhat";

const _owner = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);
const _signerAuthorityWallet = new ethers.Wallet(
	process.env.MINT_ACCOUNT_KEY!,
	ethers.provider
);

async function main(): Promise<void> {
	const CryptoArtNFT = await ethers.getContractFactory("CryptoArtNFT");

	const cryptoArtNFT = await upgrades.deployProxy(
		CryptoArtNFT,
		[
			"0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F",
			"0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F",
		],
		{
			initializer: "initialize",
		}
	);

	console.log("CryptoArtNFT deployed to:", cryptoArtNFT.target);
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
