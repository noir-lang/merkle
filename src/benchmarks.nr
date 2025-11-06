use crate::membership::check_membership;
use crate::merkle_tree::MerkleTree;
use crate::root::compute_root_from_sibling_path;
use crate::unbalanced_merkle_tree::UnbalancedMerkleTree;
use poseidon::poseidon2::Poseidon2Hasher;

#[export]
fn benchmark_get_sibling_path(tree: MerkleTree<16, Poseidon2Hasher>, leaf_index: u32) {
    let _ = tree.get_sibling_path::<4>(leaf_index);
}

// Unbalanced tree creation
#[export]
fn benchmark_unbalanced_merkle_tree_new(leaves: [Field; 16], num_non_empty_leaves: u32) {
    let _ = UnbalancedMerkleTree::<Poseidon2Hasher>::new::<16, 4>(leaves, num_non_empty_leaves);
}

#[export]
fn benchmark_root_from_sibling_path(leaf: Field, leaf_index: Field, sibling_path: [Field; 20]) {
    let _ = compute_root_from_sibling_path::<20, Poseidon2Hasher>(leaf, leaf_index, sibling_path);
}

// Membership checking
#[export]
fn benchmark_check_membership(leaf: Field, index: Field, sibling_path: [Field; 10], root: Field) {
    let _ = check_membership::<10, Poseidon2Hasher>(leaf, index, sibling_path, root);
}
