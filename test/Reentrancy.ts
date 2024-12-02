import { expect } from "chai";
import { ethers, upgrades, network } from "hardhat";
import { CryptoartNFT } from "../typechain-types";
import { MaliciousReceiver } from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

// Define MintTypes enum to match the original tests
enum MintTypesEnum {
  OpenMint = "openMint",
  Whitelist = "whitelist",
  Claimable = "claimable",
  Burn = "burn",
}

// Helper function from the original tests
const getSignatureForMint = async (
  contractAddress: CryptoartNFT,
  minter: string,
  id: number,
  signerAuthority: HardhatEthersSigner,
  mintType: string = MintTypesEnum.OpenMint,
  priceInWei: bigint = ethers.parseEther("0.01"),
  burnsToUse: number = 0,
  redeemableIndex: number = 0,
  redeemableTrueURI: string = "uri1True",
  redeemableFalseURI: string = "uri1False",
) => {
  const nonce = await contractAddress.nonces(minter);
  const chainId = network.config.chainId;
  const verifyingContract = contractAddress.target;

  const encodedData = ethers.AbiCoder.defaultAbiCoder().encode(
    [
      "address",
      "uint256",
      "string",
      "uint256",
      "uint256",
      "string",
      "string",
      "uint256",
      "uint256",
      "uint256",
      "address",
    ],
    [
      minter,
      id,
      mintType,
      priceInWei,
      burnsToUse,
      redeemableTrueURI,
      redeemableFalseURI,
      redeemableIndex,
      nonce,
      chainId,
      verifyingContract,
    ],
  );

  const digest = ethers.getBytes(ethers.keccak256(encodedData));
  const signature = await signerAuthority.signMessage(digest);

  return {
    minter,
    id,
    signature,
  };
};

describe("Reentrancy Protection Tests", function () {
  let cryptoArtNFT: CryptoartNFT;
  let maliciousReceiver: MaliciousReceiver;
  let owner: HardhatEthersSigner;
  let attacker: HardhatEthersSigner;
  let signerAuthority: HardhatEthersSigner;
  let defaultFundingAccount: HardhatEthersSigner;
  const redeemableTrueURI = "uri1True";
  const redeemableFalseURI = "uri1False";

  beforeEach(async function () {
    [defaultFundingAccount, owner, attacker, signerAuthority] =
      await ethers.getSigners();

    // Deploy NFT contract
    const CryptoArtNFTFactory = await ethers.getContractFactory(
      "CryptoartNFT",
      owner,
    );
    const proxyContract = await upgrades.deployProxy(
      CryptoArtNFTFactory,
      [owner.address, signerAuthority.address],
      {
        initializer: "initialize",
      },
    );
    cryptoArtNFT = proxyContract as unknown as CryptoartNFT;

    // Deploy malicious receiver
    const MaliciousReceiverFactory = await ethers.getContractFactory(
      "MaliciousReceiver",
    );
    maliciousReceiver = (await MaliciousReceiverFactory.deploy(
      cryptoArtNFT.target,
    )) as MaliciousReceiver;

    // Fund accounts
    const amount = ethers.parseEther("10");
    await defaultFundingAccount.sendTransaction({
      to: attacker.address,
      value: amount,
    });
  });

  it("Should prevent reentrancy attacks during mint with nonce verification", async function () {
    const tokenId1 = 1;
    const tokenId2 = 2;
    const mintPrice = ethers.parseEther("0.01");

    const maliciousReceiverAddress = await maliciousReceiver.getAddress();

    // Get signature for first mint using the helper function
    const { signature } = await getSignatureForMint(
      cryptoArtNFT,
      maliciousReceiverAddress,
      tokenId1,
      signerAuthority,
      MintTypesEnum.OpenMint,
      mintPrice,
    );

    // Set up malicious receiver with mint parameters for the reentrancy attempt
    await maliciousReceiver.setMintParams(
      tokenId2,
      MintTypesEnum.OpenMint,
      mintPrice,
      redeemableTrueURI,
      redeemableFalseURI,
      0,
      signature, // Attempting to reuse the same signature
    );

    // Mint attempt should revert with "Not authorized to mint"
    await expect(
      cryptoArtNFT
        .connect(attacker)
        .mint(
          tokenId1,
          MintTypesEnum.OpenMint,
          mintPrice,
          redeemableTrueURI,
          redeemableFalseURI,
          0,
          signature,
          {
            value: mintPrice,
          },
        ),
    ).to.be.revertedWith("Not authorized to mint");

    // Verify no state changes occurred
    expect(await cryptoArtNFT.balanceOf(maliciousReceiverAddress)).to.equal(0);
    expect(await cryptoArtNFT.balanceOf(attacker.address)).to.equal(0);
    await expect(cryptoArtNFT.ownerOf(tokenId1)).to.be.reverted;
    await expect(cryptoArtNFT.ownerOf(tokenId2)).to.be.reverted;
  });

  it("Should prevent reentrancy attacks during mintWithTrade with nonce verification", async function () {
    const tokenId1 = 1;
    const tokenId2 = 2;
    const mintPrice = ethers.parseEther("0.01");
    const maliciousReceiverAddress = await maliciousReceiver.getAddress();

    // Initial mint to get a token to trade
    const { signature: initialSignature } = await getSignatureForMint(
      cryptoArtNFT,
      attacker.address,
      tokenId1,
      signerAuthority,
      MintTypesEnum.OpenMint,
      mintPrice,
    );

    // First mint succeeds
    await cryptoArtNFT
      .connect(attacker)
      .mint(
        tokenId1,
        MintTypesEnum.OpenMint,
        mintPrice,
        redeemableTrueURI,
        redeemableFalseURI,
        0,
        initialSignature,
        { value: mintPrice },
      );

    // Get signature for the trade mint
    const { signature: tradeSignature } = await getSignatureForMint(
      cryptoArtNFT,
      maliciousReceiverAddress,
      tokenId2,
      signerAuthority,
      MintTypesEnum.OpenMint,
      mintPrice,
      1,
    );

    // Setup malicious contract for reentrancy attempt
    await maliciousReceiver.setMintParams(
      tokenId2,
      MintTypesEnum.OpenMint,
      mintPrice,
      redeemableTrueURI,
      redeemableFalseURI,
      0,
      tradeSignature,
    );

    await cryptoArtNFT
      .connect(attacker)
      .approve(maliciousReceiverAddress, tokenId1);

    // Trade mint attempt should revert
    await expect(
      cryptoArtNFT
        .connect(attacker)
        .mintWithTrade(
          tokenId2,
          [tokenId1],
          MintTypesEnum.OpenMint,
          mintPrice,
          redeemableTrueURI,
          redeemableFalseURI,
          0,
          tradeSignature,
          { value: mintPrice },
        ),
    ).to.be.revertedWith("Not authorized to mint");

    // Verify state
    expect(await cryptoArtNFT.balanceOf(maliciousReceiverAddress)).to.equal(0);
    expect(await cryptoArtNFT.balanceOf(attacker.address)).to.equal(1);
    expect(await cryptoArtNFT.ownerOf(tokenId1)).to.equal(attacker.address);
    await expect(cryptoArtNFT.ownerOf(tokenId2)).to.be.reverted;
  });

  it("Should prevent reentrancy attacks during burnAndMint with nonce verification", async function () {
    const tokenId1 = 1;
    const tokenId2 = 2;
    const mintPrice = ethers.parseEther("0.01");
    const maliciousReceiverAddress = await maliciousReceiver.getAddress();

    // Initial mint to get a token to burn
    const { signature: initialSignature } = await getSignatureForMint(
      cryptoArtNFT,
      attacker.address,
      tokenId1,
      signerAuthority,
      MintTypesEnum.OpenMint,
      mintPrice,
    );

    await cryptoArtNFT
      .connect(attacker)
      .mint(
        tokenId1,
        MintTypesEnum.OpenMint,
        mintPrice,
        redeemableTrueURI,
        redeemableFalseURI,
        0,
        initialSignature,
        { value: mintPrice },
      );

    // Get signature for burn and mint
    const { signature: burnSignature } = await getSignatureForMint(
      cryptoArtNFT,
      maliciousReceiverAddress,
      tokenId2,
      signerAuthority,
      MintTypesEnum.Burn,
      mintPrice,
      1,
    );

    // Setup malicious contract
    await maliciousReceiver.setMintParams(
      tokenId2,
      MintTypesEnum.Burn,
      mintPrice,
      redeemableTrueURI,
      redeemableFalseURI,
      0,
      burnSignature,
    );

    // Attempt burn and mint
    await expect(
      cryptoArtNFT
        .connect(attacker)
        .burnAndMint(
          [tokenId1],
          tokenId2,
          MintTypesEnum.Burn,
          mintPrice,
          1,
          redeemableTrueURI,
          redeemableFalseURI,
          0,
          burnSignature,
          { value: mintPrice },
        ),
    ).to.be.revertedWith("Not authorized to mint");

    // Verify state
    expect(await cryptoArtNFT.balanceOf(maliciousReceiverAddress)).to.equal(0);
    expect(await cryptoArtNFT.balanceOf(attacker.address)).to.equal(1);
    expect(await cryptoArtNFT.ownerOf(tokenId1)).to.equal(attacker.address);
    await expect(cryptoArtNFT.ownerOf(tokenId2)).to.be.reverted;
  });

  it("Should prevent reentrancy attacks during claimable with nonce verification", async function () {
    const tokenId1 = 1;
    const tokenId2 = 2;
    const mintPrice = ethers.parseEther("0.01");
    const maliciousReceiverAddress = await maliciousReceiver.getAddress();

    // Get signature for claim
    const { signature } = await getSignatureForMint(
      cryptoArtNFT,
      maliciousReceiverAddress,
      tokenId1,
      signerAuthority,
      MintTypesEnum.Claimable,
      mintPrice,
    );

    // Setup malicious receiver
    await maliciousReceiver.setMintParams(
      tokenId2,
      MintTypesEnum.Claimable,
      mintPrice,
      redeemableTrueURI,
      redeemableFalseURI,
      0,
      signature,
    );

    // Claim attempt should revert
    await expect(
      cryptoArtNFT
        .connect(attacker)
        .claimable(
          tokenId1,
          mintPrice,
          redeemableTrueURI,
          redeemableFalseURI,
          0,
          signature,
          { value: mintPrice },
        ),
    ).to.be.revertedWith("Not authorized to mint");

    // Verify state
    expect(await cryptoArtNFT.balanceOf(maliciousReceiverAddress)).to.equal(0);
    expect(await cryptoArtNFT.balanceOf(attacker.address)).to.equal(0);
    await expect(cryptoArtNFT.ownerOf(tokenId1)).to.be.reverted;
    await expect(cryptoArtNFT.ownerOf(tokenId2)).to.be.reverted;
  });
});
