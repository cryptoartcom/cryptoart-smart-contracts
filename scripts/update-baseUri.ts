import { ethers } from "hardhat";
import { CryptoartNFT as CryptoArtNFT } from "../typechain-types";

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
	const contractAddress = process.env.CONTRACT as string;
	const contract = (await CryptoArtNFTFactory.attach(
		contractAddress
	)) as CryptoArtNFT;

	try {
		await contract
			.connect(ownerAccount)
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
