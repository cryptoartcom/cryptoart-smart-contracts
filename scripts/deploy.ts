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
		[process.env.WALLET_NUMBER as string, process.env.WALLET_NUMBER as string],
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
