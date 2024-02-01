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
	const contractAddress = "0x8247045ca0E584487AF0FC0EbAfF42c95299529D"; // Replace with your deployed contract address
	const contract = (await CryptoArtNFTFactory.attach(
		contractAddress
	)) as CryptoArtNFT;

	try {
		await contract
			.connect(accountToMint)
			.updateMetadata(
				0,
				"bafkreibelgtnszgsraph3pgrdad2pmk6pi2wa3phu6zh3y3zkbzdme7ejq"
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
