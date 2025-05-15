| Issue | Action | Notes | Commit Hash |
|-------|--------|-------|-------------|
| [M-1] | Fix | Restrict addCreatorStory to onlyOwner. For our purposes, no creator will ever add a story - only owners.  The story chain should be a list of stories from owners only | 94bfc1b |
| [L-1] | Fix | Allow custom names | 77f34a4 |
| [L-2] | Ackowledged | Mitigation handled off-chain (URI validation pre-signing, Story string sanitization/encoding post-event) | |
| [L-3] | Fix | Add incrementNonce function | cf82aeb |
| [L-4] | Fix | Add onlyIfTokenExists to hasPinnedTokenURI | 56d0e22 |
| [L-5] | Fix | Add onlyIfTokenExists to pinTokenURI | 0409ae4 |
| [L-6] | Fix | Apply whenNotPaused to state-changing functions. Added ERC721PausableUpgradeable Inheritance | e7d7e5b |
| [I-1] | Fix | Added block.chainid to signature parameters | 1e25f8c |
| [I-2] | Fix | Add signature expiration deadline | a93977d |
| [I-3] | Fix | Cap royalties at 10% | 1d1125e |
| [I-4] | Fix | Added MintType checks to each minting function. Removed Whitelist from Enum.  We'll handle whitelisting off-chain by controlling who receives signatures. Added "Trade"as a mint type for logical consistency | deaf964 |
| [I-5] | Fix | Remove ROYALTY_BASE | 0c0dd8c |
| [G-1] | Refactor | Use named returns in tokenURIs, tokenURI functions | bdd28fa |
| [G-2] | Refactor | Replace magic numbers with named constants for token URIs | 97ef0ad |
| [G-3] | Fix | Remove onlyTokenOwner from _transferToNftReceiver | 75e179b |
| [G-4] | Refactor | Optimize tokenURI with storage reference | 591fed0 |
| [G-5] | Fix | Update burn to delete data and emit event | b554763 |
| [G-6] | Refactor | Optimize _batchBurn by removing duplicate check | 3c39fb8 |