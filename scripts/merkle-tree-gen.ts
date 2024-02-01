import { StandardMerkleTree } from "@openzeppelin/merkle-tree";

async function main(): Promise<void> {
	// Encode and create leaf hashes
	const leaf1 = ["0x1102Fe8E99b366Ef19fa9F49Ef1002B077D2Ff1F", 0];
	const leaf2 = ["0x39377075e741823D0fb2f85bc34D539E17af5926", 1];
	const leaf3 = ["0xf6b97dc33637BC27fC8Bbd2636EA52cdd13E874B", 2];
	const leaf4 = ["0x39377075e741823D0fb2f85bc34D539E17af5926", 3];

	const leaves = [leaf1, leaf2, leaf3, leaf4];

	// Create a new Merkle tree
	const tree = StandardMerkleTree.of(leaves, ["address", "uint256"]);
	const root = tree.root;

	console.log(`Merkle tree root: ${root}`);
	// Generate the proof for all the leaves
	let proof: string[] = [];
	for (const [i, v] of tree.entries()) {
		proof = tree.getProof(i);
		console.log(`Proof`, proof, "for the leave", v);
	}
}

main()
	.then(() => process.exit(0))
	.catch((error: Error) => {
		console.error(error);
		process.exit(1);
	});
