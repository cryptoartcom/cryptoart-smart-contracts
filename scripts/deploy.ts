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
	const CryptoartNFT = await ethers.getContractFactory("CryptoartNFT");

	const cryptoartNFT = await upgrades.deployProxy(
		CryptoartNFT,
		[
			"0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F",
			"0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F",
		],
		{
			initializer: "initialize",
		}
	);

	console.log("CryptoartNFT deployed to:", cryptoartNFT.target);
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
