import { ethers } from "hardhat";
import { CryptoArtNFT } from "../typechain-types";

async function main(): Promise<void> {
	const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoArtNFT");
	const provider = new ethers.InfuraProvider(
		"sepolia",
		process.env.INFURA_API_KEY as string
	);
	const ownerAccount = new ethers.Wallet(
		process.env.SEPOLIA_ACCOUNT_KEY as string,
		provider
	);

	// Connect to the deployed contract
	const contractAddress = "0x658B81d9deC39B0CffCC4d987c26159C75cEC5c5"; // Replace with your deployed contract address
	const contract = (await CryptoArtNFTFactory.attach(
		contractAddress
	)) as CryptoArtNFT;

	try {
		await contract
			.connect(ownerAccount)
			.updateMerkleRoot(
				"0xac1966dc28e3f7816e147d03b5d40a62212bd55c18ea6ce5e46903cefdb8595b"
			);
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
