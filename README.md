# Merkle Tree Library for Noir

A Merkle tree implementation for Noir with support for regular, indexed, and unbalanced trees.

## Features

- **Regular Merkle Trees** - Standard binary Merkle trees
- **Indexed Merkle Trees** - Sorted key-value trees
- **Unbalanced Merkle Trees** - Variable-size trees optimized for sparse data
- **Membership Proofs** - Proof generation and verification

## Installation

Add this library to your `Nargo.toml`:

```toml
[dependencies]
merkle = { tag = "v0.1.0", git = "https://github.com/noir-lang/merkle" }
```

## Quick Start

### Poseidon Merkle Tree

```noir
use merkle::{MerkleTree, check_membership, create_tree_with_root, create_membership_witness, verify_membership};
use poseidon::poseidon2::Poseidon2Hasher;

// Example 1: Basic Merkle Tree with Poseidon2 hasher
let leaves = [1, 2, 3, 4];
let tree = MerkleTree::<4, Poseidon2Hasher>::new(leaves);
let root = tree.get_root();

// Generate membership proof
let sibling_path = tree.get_sibling_path::<2>(1);
let is_member = check_membership::<2, Poseidon2Hasher>(2, 1, sibling_path, root);
assert(is_member, "Leaf should be in tree");

// Example 2: Using helper functions
let (tree2, root2) = create_tree_with_root::<4, Poseidon2Hasher>([10, 20, 30, 40]);
let witness = create_membership_witness::<4, 2, Poseidon2Hasher>(tree2, 0);
let verified = verify_membership::<2, Poseidon2Hasher>(10, witness, root2);
assert(verified, "Membership should be verified");
```


### Unbalanced Merkle Tree

```noir
use merkle::UnbalancedMerkleTree;
use poseidon::poseidon2::Poseidon2Hasher;

// Create unbalanced tree (any number of leaves)
let unbalanced_leaves = [1, 2, 3, 4, 5, 6, 7]; // 7 leaves (not power of 2)
let unbalanced_tree = UnbalancedMerkleTree::<Poseidon2Hasher>::new::<8, 3>(unbalanced_leaves, 7);
let unbalanced_root = unbalanced_tree.get_root();
```

### Custom Hash Functions

can check noir library std::hash::hasher for details

```noir
use merkle::{MerkleTree, create_tree_with_root};
use std::hash::Hasher;

// Define a custom hasher type that implements Hasher + Default
struct MyCustomHasher {
    // Your hasher state here
}

impl Hasher for MyCustomHasher {
    fn write(&mut self, value: Field) {
        // Write value to hasher state
    }
    
    fn finish(self) -> Field {
        // Return final hash
    }
}

impl Default for MyCustomHasher {
    fn default() -> Self {
        // Initialize hasher
    }
}

// Use custom hasher
let leaves = [1, 2, 3, 4];
let tree = MerkleTree::<4, MyCustomHasher>::new(leaves);
let root = tree.get_root();

// Or use with convenience function
let (tree2, root2) = create_tree_with_root::<4, MyCustomHasher>(leaves);
```

## API Reference

### Core Types

- `MerkleTree<N, H>` - Regular Merkle tree with N leaves (N must be power of 2) using hasher H
- `UnbalancedMerkleTree<H>` - Variable-size Merkle tree for any number of leaves using hasher H
- `MembershipWitness<K>` - Membership proof for tree of height K
- `IndexedTreeLeafPreimage<Value>` - Trait for indexed tree leaves
- `IndexedTreeLeafValue` - Trait for indexed tree values

### Hash Functions

The library uses the `Hasher` trait from `std::hash::Hasher` for Merkle tree construction. Hashers must implement `Hasher + Default`.

Common hashers:
- `Poseidon2Hasher` from `poseidon::poseidon2::Poseidon2Hasher` - Poseidon2 hasher (recommended for most use cases)
- `Sha256Hasher` from `std::hash::sha256::Sha256Hasher` - SHA256 hasher
- Custom hashers - Any type implementing `Hasher + Default`

### Tree Creation

#### Regular Merkle Trees
- `MerkleTree::<N, H>::new(leaves)` - Create tree with hasher type H
- `create_tree_with_root::<N, H>(leaves)` - Create tree with hasher H and return both tree and root

#### Unbalanced Merkle Trees
- `UnbalancedMerkleTree::<H>::new::<N, MAX_SUBTREES>(leaves, num_leaves)` - Create unbalanced tree with hasher H

### Tree Operations

#### Basic Operations
- `tree.get_root()` - Get tree root
- `tree.get_sibling_path::<K>(leaf_index)` - Generate membership proof

#### Membership Proofs
- `check_membership::<K, H>(leaf, index, path, root)` - Verify membership (returns bool)
- `assert_check_membership::<TREE_HEIGHT, H>(leaf, index, path, root)` - Assert membership (panics if false)
- `assert_check_non_membership::<TREE_HEIGHT, LEAF_PREIMAGE, VALUE, H>(key, low_leaf, witness, root)` - Verify non-membership
- `create_membership_witness::<N, K, H>(tree, leaf_index)` - Generate complete witness
- `verify_membership::<K, H>(leaf, witness, root)` - Verify using witness

#### Utility Functions
- `compute_root_from_sibling_path::<N, H>(leaf, index, path)` - Reconstruct root from proof
- `calculate_empty_tree_root::<H>(depth)` - Calculate empty tree root for hasher H
- `calculate_empty_tree_root_poseidon(depth)` - Get precomputed empty tree root for Poseidon2

### Indexed Tree Operations

#### Insertion
- `insert::<Value, Leaf, TREE_HEIGHT, H>(root, next_index, value, low_leaf, witness, path)` - Insert single value
- `batch_insert::<Value, Leaf, SubtreeWidth, SiblingPathLength, SubtreeHeight, TreeHeight, H>(root, next_index, values, sorted_values, ...)` - Insert multiple values

#### Validation
- `assert_check_valid_low_leaf(value, low_leaf, witness, root)` - Validate insertion position

## Noir Version Compatibility

Tested with Noir version 1.0.0-beta.11 or up

## Benchmarks

Generate performance benchmarks:

```bash
nargo export
./scripts/build-gates-report.sh
```

Results are saved to `./gates_report.json`.
