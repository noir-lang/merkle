# Merkle Tree Library for Noir

A comprehensive Merkle tree implementation for Noir with support for regular, indexed, and unbalanced trees.

## Features

- **Regular Merkle Trees** - Standard binary Merkle trees
- **Indexed Merkle Trees** - Sorted key-value trees with efficient insertions and range queries  
- **Unbalanced Merkle Trees** - Variable-size trees optimized for sparse data
- **Membership Proofs** - Efficient proof generation and verification
- **High Performance** - Optimized for zero-knowledge circuits

## Installation

Add this library to your `Nargo.toml`:

```toml
[dependencies]
merkle = { tag = "v0.1.0", git = "https://github.com/noir-lang/merkle" }
```

## Quick Start

### Basic Merkle Tree

```noir
use merkle::{MerkleTree, check_membership, MembershipWitness};

// Create a tree with 4 leaves
let leaves = [1, 2, 3, 4];
let tree = MerkleTree::new(leaves);

// Get the root
let root = tree.get_root();

// Generate membership proof for leaf at index 1
let sibling_path = tree.get_sibling_path::<2>(1);

// Verify membership
let is_member = check_membership(2, 1, sibling_path, root);
assert(is_member, "Leaf should be in tree");
```

### SHA256 Merkle Tree

```noir
use merkle::MerkleTree;

// Create tree with SHA256 hashing
let tree = MerkleTree::new_sha(leaves);
let root = tree.get_root();
```

### Unbalanced Merkle Tree

```noir
use merkle::UnbalancedMerkleTree;

// Create unbalanced tree (any number of leaves)
let leaves = [1, 2, 3, 4, 5, 6, 7]; // 7 leaves (not power of 2)
let tree = UnbalancedMerkleTree::new_sha::<8, 3>(leaves, 7);
let root = tree.get_root();
```

## API Reference

### Core Types

- `MerkleTree<N>` - Regular Merkle tree with N leaves (N must be power of 2)
- `UnbalancedMerkleTree` - Variable-size Merkle tree
- `MembershipWitness<N>` - Membership proof for tree of height N

### Key Functions

#### Tree Creation
- `MerkleTree::new(leaves)` - Create tree with Poseidon2 hash
- `MerkleTree::new_sha(leaves)` - Create tree with SHA256 hash
- `UnbalancedMerkleTree::new_sha(leaves, num_leaves)` - Create unbalanced tree

#### Tree Operations
- `tree.get_root()` - Get tree root
- `tree.get_sibling_path::<K>(leaf_index)` - Generate membership proof
- `check_membership(leaf, index, path, root)` - Verify membership
- `assert_check_membership(leaf, index, path, root)` - Assert membership

#### Utility Functions
- `sibling_index(index)` - Get sibling index
- `root_from_sibling_path(leaf, index, path)` - Reconstruct root from proof
- `calculate_subtree_root(leaves)` - Calculate subtree root
- `calculate_empty_tree_root(depth)` - Get empty tree root

## Advanced Usage

### Indexed Merkle Trees

For sorted key-value data with efficient range queries:

```noir
use merkle::{IndexedTreeLeafPreimage, IndexedTreeLeafValue, batch_insert};

// Implement traits for your data type
struct MyLeaf {
    key: Field,
    value: Field,
    next_key: Field,
}

impl IndexedTreeLeafValue for Field {
    fn get_key(self) -> Field { self }
    fn is_empty(self) -> bool { self == 0 }
    fn empty() -> Self { 0 }
}

impl IndexedTreeLeafPreimage<Field> for MyLeaf {
    // ... implement required methods
}
```

## Noir Version Compatibility

Tested with Noir version 1.0.0-beta.11 or up

## Benchmarks

Generate performance benchmarks:

```bash
./scripts/build-gates-report.sh
```

Results are saved to `./gates_report.json`.
