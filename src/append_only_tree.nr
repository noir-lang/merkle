use crate::membership::assert_check_membership;
use crate::root::compute_root_from_sibling_path;
use std::hash::Hasher;

pub fn insert_subtree_to_snapshot_tree<let N: u32, H>(
    current_root: Field,
    next_available_leaf_index: u64,
    sibling_path: [Field; N],
    empty_subtree_root: Field,
    subtree_root_to_insert: Field,
    subtree_depth: u8,
) -> (Field, u64)
where
    H: Hasher + Default,
{
    // TODO(Lasse): Sanity check len of sibling_path > height of subtree
    // TODO(Lasse): Ensure height of subtree is correct (eg 3 for commitments, 1 for contracts)
    let leaf_index_at_depth = (next_available_leaf_index >> (subtree_depth as u64)) as u32;

    // Check that the current root is correct and that there is an empty subtree at the insertion location
    assert_check_membership::<N, H>(
        empty_subtree_root,
        leaf_index_at_depth as Field,
        sibling_path,
        current_root,
    );

    // if index of leaf is x, index of its parent is x/2 or x >> 1. We need to find the parent `subtree_depth` levels up.
    let new_root = compute_root_from_sibling_path::<N, H>(
        subtree_root_to_insert,
        leaf_index_at_depth as Field,
        sibling_path,
    );

    // 2^subtree_depth is the number of leaves added. 2^x = 1 << x
    let new_next_available_leaf_index = next_available_leaf_index + (1 << (subtree_depth as u64));

    (new_root, new_next_available_leaf_index)
}
