pub mod append_only_tree;
pub mod indexed_tree;
pub mod leaf_preimage;
pub mod membership;
pub mod merkle_tree;
pub mod root;
pub mod unbalanced_merkle_tree;
mod benchmarks;
mod utils;

// Re-export commonly used types and functions for convenience
pub use merkle_tree::MerkleTree;
pub use unbalanced_merkle_tree::UnbalancedMerkleTree;
pub use leaf_preimage::{IndexedTreeLeafPreimage, LeafPreimage, IndexedTreeLeafValue};
pub use membership::{assert_check_membership, assert_check_non_membership, check_membership, conditionally_assert_check_membership, MembershipWitness};
pub use root::{calculate_empty_tree_root, calculate_subtree_root, root_from_sibling_path};
pub use merkle_tree::sibling_index;
pub use utils::{merkle_hash, accumulate_sha256, create_tree_with_root, create_sha_tree_with_root, create_membership_witness, verify_membership, create_and_verify_membership, reconstruct_root};
pub use indexed_tree::{batch_insert, insert};
pub use append_only_tree::insert_subtree_to_snapshot_tree;
