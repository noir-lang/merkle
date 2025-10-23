use crate::root::compute_root_from_sibling_path;
use crate::utils::poseidon2_hash;

#[export]
fn benchmark_root_from_sibling_path(leaf: Field, leaf_index: Field, sibling_path: [Field; 20]) {
    compute_root_from_sibling_path(leaf, leaf_index, sibling_path, poseidon2_hash);
}
