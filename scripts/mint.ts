import { ethers } from 'hardhat';
import { CryptoArtNFT } from '../typechain-types';

async function main(): Promise<void> {
  const CryptoArtNFTFactory = await ethers.getContractFactory('CryptoArtNFT');
  const provider = new ethers.InfuraProvider(
    'sepolia',
    'ef5c71f0aa144eb89fbef447df6df86c'
  );
  const accountToMint = new ethers.Wallet(
    '04ceada767573623bf9ca85dce3e7697c255411c64d23b45cb498669a75c6b97',
    provider
  );

  // Connect to the deployed contract
  const contractAddress = '0xaee9809850928456acac23961773d45cd8b009f6'; // Replace with your deployed contract address
  const contract = (await CryptoArtNFTFactory.attach(
    contractAddress
  )) as CryptoArtNFT;

  try {
    await contract
      .connect(accountToMint)
      .mint(
        1,
        'bafkreibelgtnszgsraph3pgrdad2pmk6pi2wa3phu6zh3y3zkbzdme7ejq',
        [
          '0x4ac8c14c9c0dcc3180014ef1288354dd7c2cd1d2d3328f82172fd3c6ca838ef2',
          '0xf7778a2cf5f7d762ff9f470e1d6259da17f190ceb15b55ca2207b41d789de649',
        ],
        { value: ethers.parseUnits('0.0001', 18) }
      );
  } catch (error) {
    console.log('Failed!!!', error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error: Error) => {
    console.error(error);
    process.exit(1);
  });
