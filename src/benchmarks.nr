use crate::root::root_from_sibling_path;
use crate::merkle_tree::compute_merkle_tree_nodes;
use types::hash::merkle_hash;

#[export]
fn benchmark_root_from_sibling_path(leaf: Field, leaf_index: Field, sibling_path: [Field; 20]) {
    root_from_sibling_path(leaf, leaf_index, sibling_path);
}

#[export]
fn benchmark_compute_merkle_tree_nodes(leaves: [Field; 20]) {
    compute_merkle_tree_nodes(leaves, merkle_hash);
}