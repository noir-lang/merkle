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
use merkle::{MerkleTree, check_membership, create_poseidon_tree_with_root, create_membership_witness, verify_membership, poseidon2_hash};

// Example 1: Basic Merkle Tree with poseidon hash function
let leaves = [1, 2, 3, 4];
let tree = MerkleTree::new(leaves, poseidon2_hash);
let root = tree.get_root();

// Generate membership proof
let sibling_path = tree.get_sibling_path::<2>(1);
let is_member = check_membership(2, 1, sibling_path, root);
assert(is_member, "Leaf should be in tree");

// Example 2: Using helper functions
let (tree2, root2) = create_poseidon_tree_with_root([10, 20, 30, 40]);
let witness = create_membership_witness::<4, 2>(tree2, 0);
let verified = verify_membership(10, witness, root2);
assert(verified, "Membership should be verified");
```

### SHA256 Merkle Tree

```noir
use merkle::{MerkleTree, create_sha256_tree_with_root, accumulate_sha256};

// Create tree with SHA256 hashing using helper function
let (sha_tree, sha_root) = create_sha256_tree_with_root([100, 200, 300, 400]);
```

### Unbalanced Merkle Tree

```noir
use merkle::{UnbalancedMerkleTree, accumulate_sha256};

// Create unbalanced tree (any number of leaves)
let unbalanced_leaves = [1, 2, 3, 4, 5, 6, 7]; // 7 leaves (not power of 2)
let unbalanced_tree = UnbalancedMerkleTree::new_sha256::<8, 3>(unbalanced_leaves, 7);
let unbalanced_root = unbalanced_tree.get_root();

// Or create with custom hash function
let unbalanced_tree2 = UnbalancedMerkleTree::new::<8, 3>(unbalanced_leaves, 7, accumulate_sha256);
let unbalanced_root2 = unbalanced_tree2.get_root();
```

### Custom Hash Functions

```noir
use merkle::{MerkleTree, create_tree_with_root};

// Define a custom hash function
fn my_custom_hash(left: Field, right: Field) -> Field {
    // Your custom hashing logic here
    // For example, simple addition (not recommended for production!)
    left + right
}

// Use custom hash function
let leaves = [1, 2, 3, 4];
let tree = MerkleTree::new(leaves, my_custom_hash);
let root = tree.get_root();

// Or use with convenience function
let (tree2, root2) = create_tree_with_root(leaves, my_custom_hash);
```

## API Reference

### Core Types

- `MerkleTree<N>` - Regular Merkle tree with N leaves (N must be power of 2)
- `UnbalancedMerkleTree` - Variable-size Merkle tree for any number of leaves
- `MembershipWitness<K>` - Membership proof for tree of height K
- `IndexedTreeLeafPreimage<Value>` - Trait for indexed tree leaves
- `IndexedTreeLeafValue` - Trait for indexed tree values

### Hash Functions

The library supports many hash functions for Merkle tree construction:

- `poseidon2_hash(left, right)` - Poseidon2 hash function (default for Poseidon trees)
- `accumulate_sha256(left, right)` - accumulate SHA256 hash function (default for SHA256 trees)
- Custom hash functions - Any function with signature `fn(Field, Field) -> Field`

### Tree Creation

#### Regular Merkle Trees
- `MerkleTree::new(leaves, hasher)` - Create tree with custom hash function
- `MerkleTree::new_poseidon(leaves)` - Create tree with Poseidon2 hash
- `MerkleTree::new_sha256(leaves)` - Create tree with SHA256 hash
- `create_tree_with_root(leaves, hasher)` - Create tree with custom hash and return both tree and root
- `create_poseidon_tree_with_root(leaves)` - Create Poseidon tree and return both tree and root
- `create_sha256_tree_with_root(leaves)` - Create SHA256 tree and return both tree and root

#### Unbalanced Merkle Trees
- `UnbalancedMerkleTree::new(leaves, num_leaves, hasher)` - Create unbalanced tree with custom hash function
- `UnbalancedMerkleTree::new_sha256(leaves, num_leaves)` - Create unbalanced tree with SHA256 hash

### Tree Operations

#### Basic Operations
- `tree.get_root()` - Get tree root
- `tree.get_sibling_path::<K>(leaf_index)` - Generate membership proof

#### Membership Proofs
- `check_membership(leaf, index, path, root, hasher)` - Verify membership (returns bool)
- `assert_check_membership(leaf, index, path, root, hasher)` - Assert membership (panics if false)
- `check_non_membership(leaf, index, path, root, hasher)` - Verify non-membership
- `create_membership_witness(tree, leaf_index)` - Generate complete witness
- `verify_membership(leaf, witness, root, hasher)` - Verify using witness

#### Utility Functions
- `compute_root_from_sibling_path(leaf, index, path, hasher)` - Reconstruct root from proof
- `calculate_empty_tree_root_poseidon(depth)` - Get precomputed empty tree root

### Indexed Tree Operations

#### Insertion
- `insert(root, next_index, value, low_leaf, witness, path, hasher)` - Insert single value
- `batch_insert(root, next_index, values, sorted_values, ...)` - Insert multiple values

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
