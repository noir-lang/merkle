pub mod check_valid_low_leaf;

use crate::indexed_tree::check_valid_low_leaf::assert_check_valid_low_leaf;
use crate::leaf_preimage::{IndexedTreeLeafPreimage, IndexedTreeLeafValue};
use crate::membership::{assert_check_membership, MembershipWitness};
use crate::merkle_tree::MerkleTree;
use crate::root::{calculate_empty_tree_root, compute_root_from_sibling_path};
use crate::utils::create_tree_with_root;
use dep::check_shuffle::{check_shuffle, get_shuffle_indices};
use std::hash::Hasher;

// create a new indexed tree with no leaves, add leaf 0 as placeholder, return the root and the next available leaf index.
// Then once a new leaf is inserted, the placeholder is updated to point to the new leaf.
pub fn new<Value, Leaf, let TreeHeight: u32, let TreeWidth: u32, H>() -> (Field, u32)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
    H: Hasher + Default,
{
    assert_eq(TreeWidth, 1 << TreeHeight, "subtree items must be 2^subtree height");
    let leaf_0 = Leaf::empty().as_leaf();
    let tree = MerkleTree::<TreeWidth, H>::empty();
    let sibling_path = tree.get_sibling_path::<TreeHeight>(0);
    let root = compute_root_from_sibling_path::<TreeHeight, H>(leaf_0, 0, sibling_path);
    (root, 1)
}

pub fn batch_insert<Value, Leaf, let SubtreeWidth: u32, let SubtreeHeight: u32, let TreeHeight: u32, H>(
    start_root: Field,
    start_next_available_leaf_index: u32,
    values_to_insert: [Value; SubtreeWidth],
    sorted_values: [Value; SubtreeWidth],
    // sorted in DESCENDING order
    new_subtree_sibling_path: [Field; TreeHeight - SubtreeHeight],
    low_leaf_preimages: [Leaf; SubtreeWidth],
    low_leaf_membership_witnesses: [MembershipWitness<TreeHeight>; SubtreeWidth],
) -> (Field, u32)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
    H: Hasher + Default,
{
    // A permutation to the values is provided to make the insertion use only one insertion strategy
    // However, for the actual insertion in the tree the original order is respected, the sorting is only used for validation of the links
    // and low leaf updates.

    assert_eq(SubtreeWidth, 1 << SubtreeHeight, "subtree items must be 2^subtree height");
    check_shuffle(values_to_insert, sorted_values);
    let sorted_values_indexes = get_shuffle_indices(values_to_insert, sorted_values);

    assert(
        start_next_available_leaf_index % SubtreeWidth == 0,
        "Start next available leaf index must be a multiple of the subtree width",
    );

    // Now, update the existing leaves with the new leaves
    let mut current_tree_root = start_root;
    let mut insertion_subtree = [Leaf::empty(); SubtreeWidth];

    for i in 0..sorted_values.len() {
        let value = sorted_values[i];
        if !value.is_empty() {
            let low_leaf_preimage = low_leaf_preimages[i];
            let witness = low_leaf_membership_witnesses[i];

            // validate the low leaf
            assert(!low_leaf_preimage.is_empty(), "Empty low leaf");
            let value_key = value.get_key();

            assert_check_valid_low_leaf(value_key, low_leaf_preimage);

            // perform membership check for the low leaf against the original root
            assert_check_membership::<TreeHeight, H>(
                low_leaf_preimage.as_leaf(),
                witness.leaf_index,
                witness.sibling_path,
                current_tree_root,
            );

            let value_index = sorted_values_indexes[i];

            // Calculate the new value of the low_leaf
            let updated_low_leaf = low_leaf_preimage.update_pointers(
                value_key,
                start_next_available_leaf_index + value_index,
            );

            current_tree_root = compute_root_from_sibling_path::<TreeHeight, H>(
                updated_low_leaf.as_leaf(),
                witness.leaf_index,
                witness.sibling_path,
            );

            insertion_subtree[value_index] = Leaf::build_insertion_leaf(value, low_leaf_preimage);
        }
    }

    let empty_subtree_root = calculate_empty_tree_root::<H>(SubtreeHeight);
    let leaf_index_subtree_depth = start_next_available_leaf_index >> SubtreeHeight;

    assert_check_membership::<TreeHeight - SubtreeHeight, H>(
        empty_subtree_root,
        leaf_index_subtree_depth as Field,
        new_subtree_sibling_path,
        current_tree_root,
    );

    // Create new subtree to insert into the whole indexed tree
    let (_, subtree_root) = create_tree_with_root::<SubtreeWidth, H>(insertion_subtree
        .map(|leaf: Leaf| leaf.as_leaf()));

    // Calculate the new root
    // We are inserting a subtree rather than a full tree here
    let subtree_index = start_next_available_leaf_index >> SubtreeHeight;
    let new_root = compute_root_from_sibling_path::<TreeHeight - SubtreeHeight, H>(
        subtree_root,
        subtree_index as Field,
        new_subtree_sibling_path,
    );

    (new_root, start_next_available_leaf_index + values_to_insert.len())
}

pub fn insert<Value, Leaf, let TreeHeight: u32, H>(
    mut current_root: Field,
    mut next_available_leaf_index: u32,
    value: Value,
    low_leaf_preimage: Leaf,
    low_leaf_membership_witness: MembershipWitness<TreeHeight>,
    insertion_sibling_path: [Field; TreeHeight],
) -> (Field, u32)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
    H: Hasher + Default,
{
    batch_insert::<Value, Leaf, 1, 0, TreeHeight, H>(
        current_root,
        next_available_leaf_index,
        [value],
        [value],
        // sorted in DESCENDING order
        insertion_sibling_path,
        [low_leaf_preimage],
        [low_leaf_membership_witness],
    )
}
