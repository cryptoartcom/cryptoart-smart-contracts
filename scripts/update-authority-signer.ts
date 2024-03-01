import { ethers } from "hardhat";
import { CryptoArtNFT } from "../typechain-types";

async function main(): Promise<void> {
	const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoArtNFT");
	const provider = new ethers.InfuraProvider(
		"sepolia",
		process.env.INFURA_API_KEY as string
	);
	const accountToMint = new ethers.Wallet(
		process.env.MINT_ACCOUNT_KEY as string,
		provider
	);

	// Connect to the deployed contract
	const contractAddress = "0xa9d573506bE0e7e5712C158fAC1C63A11a225235"; // Replace with your deployed contract address
	const contract = (await CryptoArtNFTFactory.attach(
		contractAddress
	)) as CryptoArtNFT;

	try {
		await contract
			.connect(accountToMint)
			.updateAuthoritySigner("0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F");
	} catch (error) {
		console.log("Failed!!!", error);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
