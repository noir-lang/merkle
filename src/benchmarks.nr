use crate::membership::check_membership;
use crate::merkle_tree::MerkleTree;
use crate::root::root_from_sibling_path;
use crate::unbalanced_merkle_tree::compute_unbalanced_merkle_root;
use crate::unbalanced_merkle_tree::UnbalancedMerkleTree;
use types::hash::accumulate_sha256;

// new Merkle tree
#[export]
fn benchmark_merkle_tree_with_poseidon(leaves: [Field; 16]) {
    MerkleTree::new(leaves);
}

#[export]
fn benchmark_merkle_tree_with_sha256(leaves: [Field; 16]) {
    MerkleTree::new_sha(leaves);
}

#[export]
fn benchmark_get_sibling_path(tree: MerkleTree<16>, leaf_index: u32) {
    tree.get_sibling_path::<4>(leaf_index);
}

// Unbalanced tree creation
#[export]
fn benchmark_unbalanced_merkle_tree_new(leaves: [Field; 16], num_non_empty_leaves: u32) {
    UnbalancedMerkleTree::new_sha::<16, 4>(leaves, num_non_empty_leaves);
}

// Unbalanced root computation
#[export]
fn benchmark_compute_unbalanced_merkle_root(leaves: [Field; 16], num_non_empty_leaves: u32) {
    compute_unbalanced_merkle_root::<16, 4>(leaves, num_non_empty_leaves, accumulate_sha256);
}

#[export]
fn benchmark_root_from_sibling_path(leaf: Field, leaf_index: Field, sibling_path: [Field; 20]) {
    root_from_sibling_path(leaf, leaf_index, sibling_path);
}

// Membership checking
#[export]
fn benchmark_check_membership(leaf: Field, index: Field, sibling_path: [Field; 10], root: Field) {
    check_membership(leaf, index, sibling_path, root);
}
