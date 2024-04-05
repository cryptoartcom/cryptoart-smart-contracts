import { ethers } from "hardhat";
import { CryptoArtNFT } from "../typechain-types";

async function main(): Promise<void> {
	const CryptoArtNFTFactory = await ethers.getContractFactory("CryptoArtNFT");
	const provider = new ethers.InfuraProvider(
		"sepolia",
		process.env.INFURA_API_KEY as string
	);

	// Use the account that currently owns the NFT
	const sellerAccount = new ethers.Wallet(
		process.env.MINT_ACCOUNT_KEY as string,
		provider
	);

	// Address of the recipient account (could be another wallet controlled by you for testing)
	const recipientAddress = "0x39377075e741823D0fb2f85bc34D539E17af5926"; // Replace with the recipient's address

	const contractAddress = "0xF3AB7991ce6Bccb53331fa9CB9aA6599699774F5"; // Your deployed contract's address
	const contract = CryptoArtNFTFactory.attach(contractAddress).connect(
		sellerAccount
	) as CryptoArtNFT;

	const tokenId = 6211; // The token you want to sell
	const salePrice = ethers.parseEther("0.01"); // Example sale price in ETH

	// Retrieve and log royalty info for the sale
	const [royaltyReceiver, royaltyAmount] = await contract.royaltyInfo(
		tokenId,
		salePrice
	);

	console.log(
		`Royalty info - Receiver: ${royaltyReceiver}, Amount: ${ethers.formatEther(
			royaltyAmount
		)} ETH`
	);

	// Perform the sale - simulate a direct transfer from seller to recipient
	try {
		console.log(`Transferring token ID ${tokenId} to ${recipientAddress}`);
		const transferTx = await contract[
			"safeTransferFrom(address,address,uint256)"
		](sellerAccount.address, recipientAddress, tokenId);
		await transferTx.wait();
		console.log(`Transfer complete.`);

		// Simulate sending the royalty payment
		console.log(`Simulating royalty payment to ${royaltyReceiver}`);
		const royaltyTx = await sellerAccount.sendTransaction({
			to: royaltyReceiver,
			value: royaltyAmount,
		});
		await royaltyTx.wait();
		console.log(
			`Royalty payment of ${ethers.formatEther(
				royaltyAmount
			)} ETH sent to ${royaltyReceiver}`
		);
	} catch (error) {
		console.error("Transaction failed", error);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error) => {
		console.error(error);
		process.exit(1);
	});
