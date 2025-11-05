pub mod check_valid_low_leaf;

use crate::leaf_preimage::{IndexedTreeLeafPreimage, IndexedTreeLeafValue};
use crate::membership::{assert_check_membership, MembershipWitness};
use crate::root::{calculate_empty_tree_root, compute_root_from_sibling_path};
use crate::utils::{check_permutation, create_tree_with_root};
pub fn batch_insert<Value, Leaf, let SubtreeWidth: u32, let SiblingPathLength: u32, let SubtreeHeight: u32, let TreeHeight: u32>(
    start_root: Field,
    start_next_available_leaf_index: u64,
    values_to_insert: [Value; SubtreeWidth],
    sorted_values: [Value; SubtreeWidth],
    sorted_values_indexes: [u32; SubtreeWidth],
    new_subtree_sibling_path: [Field; SiblingPathLength],
    low_leaf_preimages: [Leaf; SubtreeWidth],
    low_leaf_membership_witnesses: [MembershipWitness<TreeHeight>; SubtreeWidth],
    hasher: fn(Field, Field) -> Field,
) -> (Field, u64)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
{
    // A permutation to the values is provided to make the insertion use only one insertion strategy
    // However, for the actual insertion in the tree the original order is respected, the sorting is only used for validation of the links
    // and low leaf updates.
    check_permutation(values_to_insert, sorted_values, sorted_values_indexes);
    assert(1 << (SubtreeHeight as u32) == SubtreeWidth, "Subtree width must be a power of 2");
    assert(start_next_available_leaf_index % SubtreeWidth as u64 == 0 as u64, "Start next available leaf index must be a multiple of the subtree width");

    // update the existing leaves with the new leaves
    let mut current_tree_root = start_root;
    let mut insertion_subtree = [Leaf::empty(); SubtreeWidth];
    let start_insertion_index = start_next_available_leaf_index;
    let mut prev_leaf: Leaf = Leaf::empty();
    let mut prev_leaf_index: u32 = 0xFFFFFFFFu32;

    for i in 0..sorted_values.len() {
        let value = sorted_values[i];
        if !value.is_empty() {
            let low_leaf_preimage = low_leaf_preimages[i];
            let witness = low_leaf_membership_witnesses[i];

            // validate the low leaf
            assert(!low_leaf_preimage.is_empty(), "Empty low leaf");
            let value_key = value.get_key();
            let low_leaf_key = low_leaf_preimage.get_key();
            let low_leaf_next_key = low_leaf_preimage.get_next_key();
            let is_update = value_key == low_leaf_key;

            let is_less_than_slot = low_leaf_key.lt(value_key);
            let is_next_greater_than = value_key.lt(low_leaf_next_key);
            let is_in_range =
                is_less_than_slot & (is_next_greater_than | low_leaf_preimage.points_to_infinity());
            let is_less_than_prev_leaf = value_key.lt(prev_leaf.get_key());
            let is_greater_than_prev_leaf = prev_leaf.get_next_key().lt(value_key);
            let is_in_range_prev_leaf: bool = !prev_leaf.is_empty() & is_less_than_prev_leaf & (is_greater_than_prev_leaf | prev_leaf.points_to_infinity());

            assert(is_update | is_in_range | is_in_range_prev_leaf, "Invalid low leaf");

            if is_update | is_in_range {
                // perform membership check for the low leaf against the original root
                assert_check_membership(
                    low_leaf_preimage.as_leaf(),
                    witness.leaf_index,
                    witness.sibling_path,
                    current_tree_root,
                    hasher,
                );
            }

            let value_index = sorted_values_indexes[i];

            // Calculate the new value of the low_leaf
            let updated_low_leaf = if is_update {
                low_leaf_preimage.update_value(value)
            } else if is_in_range {
                low_leaf_preimage.update_pointers(
                    value_key,
                    start_insertion_index as u32 + value_index,
                )
            } else {
                prev_leaf.update_pointers(
                    value_key,
                    start_insertion_index as u32 + value_index,
                )
            };

            // Update the tree root if we're updating a leaf that exists in the tree
            if is_update | is_in_range {
                current_tree_root = compute_root_from_sibling_path(
                    updated_low_leaf.as_leaf(),
                    witness.leaf_index,
                    witness.sibling_path,
                    hasher,
                );
            }

            // If using prev_leaf, update the previous leaf in insertion_subtree because next pointer has changed
            if is_in_range_prev_leaf {
                assert(prev_leaf_index != 0xFFFFFFFFu32, "prev_leaf_index should be set when using prev_leaf");
                // Update the previous leaf in insertion_subtree to point to the new leaf
                insertion_subtree[prev_leaf_index] = updated_low_leaf;
            }

            // Create the new leaf in insertion_subtree
            insertion_subtree[value_index] = if is_update {
                Leaf::empty()
            } else if is_in_range {
                Leaf::build_insertion_leaf(value, low_leaf_preimage)
            } else {
                // Use the updated prev_leaf
                Leaf::build_insertion_leaf(value, updated_low_leaf)
            };

            // Update prev_leaf for next iteration
            if !is_update {
                prev_leaf = insertion_subtree[value_index];
                prev_leaf_index = value_index;
            }
        }
    }

    let empty_subtree_root = calculate_empty_tree_root(SubtreeHeight, hasher);
    let leaf_index_subtree_depth = (start_insertion_index >> (SubtreeHeight as u64)) as u32;

    assert_check_membership(
        empty_subtree_root,
        leaf_index_subtree_depth as Field,
        new_subtree_sibling_path,
        current_tree_root,
        hasher,
    );

    // Create new subtree to insert into the whole indexed tree
    let (_, subtree_root) =
        create_tree_with_root(insertion_subtree.map(|leaf: Leaf| leaf.as_leaf()), hasher);

    // Calculate the new root
    // We are inserting a subtree rather than a full tree here
    let new_root = compute_root_from_sibling_path(
        subtree_root,
        leaf_index_subtree_depth as Field,
        new_subtree_sibling_path,
        hasher,
    );

    (new_root, start_insertion_index + (values_to_insert.len() as u64))
}

pub fn insert<Value, Leaf, let TreeHeight: u32>(
    mut current_root: Field,
    mut next_available_leaf_index: u64,
    value: Value,
    low_leaf_preimage: Leaf,
    low_leaf_membership_witness: MembershipWitness<TreeHeight>,
    insertion_sibling_path: [Field; TreeHeight],
    hasher: fn(Field, Field) -> Field,
) -> (Field, u64)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
{
    // validate the low leaf
    assert(!low_leaf_preimage.is_empty(), "Empty low leaf");
    let value_key = value.get_key();
    let low_leaf_key = low_leaf_preimage.get_key();
    let low_leaf_next_key = low_leaf_preimage.get_next_key();
    let is_update = value_key == low_leaf_key;

    let is_less_than_slot = low_leaf_key.lt(value_key);
    let is_next_greater_than = value_key.lt(low_leaf_next_key);
    let is_in_range =
        is_less_than_slot & (is_next_greater_than | low_leaf_preimage.points_to_infinity());

    assert(is_update | is_in_range, "Invalid low leaf");

    // perform membership check for the low leaf against the original root
    assert_check_membership(
        low_leaf_preimage.as_leaf(),
        low_leaf_membership_witness.leaf_index,
        low_leaf_membership_witness.sibling_path,
        current_root,
        hasher,
    );

    // Calculate the new value of the low_leaf
    let updated_low_leaf = if is_update {
        low_leaf_preimage.update_value(value)
    } else {
        low_leaf_preimage.update_pointers(value_key, next_available_leaf_index as u32)
    };

    // Update low leaf
    current_root = compute_root_from_sibling_path(
        updated_low_leaf.as_leaf(),
        low_leaf_membership_witness.leaf_index,
        low_leaf_membership_witness.sibling_path,
        hasher,
    );

    if is_update {
        // If it's an update, we don't need to insert the new leaf and advance the tree
        (current_root, next_available_leaf_index)
    } else {
        let insertion_leaf = Leaf::build_insertion_leaf(value, low_leaf_preimage);
        assert_check_membership(
            0,
            next_available_leaf_index as Field,
            insertion_sibling_path,
            current_root,
            hasher,
        );

        // Calculate the new root
        current_root = compute_root_from_sibling_path(
            insertion_leaf.as_leaf(),
            next_available_leaf_index as Field,
            insertion_sibling_path,
            hasher,
        );

        next_available_leaf_index += 1;

        (current_root, next_available_leaf_index)
    }
}

mod tests {
    use crate::{
        indexed_tree::batch_insert,
        leaf_preimage::{IndexedTreeLeafPreimage, LeafPreimage},
        membership::MembershipWitness,
        utils::{create_membership_witness, create_tree_with_root, poseidon2_hash},
    };

    struct TestLeafPreimage {
        value: Field,
        next_value: Field,
    }

    impl LeafPreimage for TestLeafPreimage {
        fn get_key(self) -> Field {
            self.value
        }

        fn as_leaf(self) -> Field {
            self.value
        }
    }

    impl Eq for TestLeafPreimage {
        fn eq(self, other: Self) -> bool {
            (self.value == other.value) & (self.next_value == other.next_value)
        }
    }

    impl IndexedTreeLeafPreimage<Field> for TestLeafPreimage {
        fn get_next_key(self) -> Field {
            self.next_value
        }

        fn points_to_infinity(self) -> bool {
            (self.next_value == 0)
        }

        fn update_pointers(self, next_value: Field, _next_index: u32) -> Self {
            Self { value: self.value, next_value }
        }

        fn update_value(self, value: Field) -> Self {
            Self { value, next_value: self.next_value }
        }

        fn build_insertion_leaf(value: Field, low_leaf: Self) -> Self {
            Self { value, next_value: low_leaf.next_value }
        }

        fn is_empty(self) -> bool {
            (self.value == 0) & (self.next_value == 0)
        }

        fn empty() -> Self {
            Self { value: 0, next_value: 0 }
        }
    }


    #[test]
    fn test_batch_insert() {
        // Test inserting 4 values (25, 35, 45, 55) 
        // Initial tree has leaves: 10, 20, 30, 40
        let initial_leaves = [10, 20, 30, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        let (tree, start_root) = create_tree_with_root(initial_leaves, poseidon2_hash);

        // Values to insert: 25, 35, 45, 55
        let values_to_insert: [Field; 4] = [25, 26, 45, 55];
        let sorted_values: [Field; 4] = [25, 26, 45, 55];
        let sorted_values_indexes: [u32; 4] = [0, 1, 2, 3];

        let low_leaf_preimages: [TestLeafPreimage; 4] = [
            TestLeafPreimage { value: 20, next_value: 30 }, // 25 goes between 20 and 30
            TestLeafPreimage { value: 20, next_value: 30 }, // 26 goes between 20 and 30
            TestLeafPreimage { value: 40, next_value: 0 }, // 45 goes after 40
            TestLeafPreimage { value: 40, next_value: 0 },  // 55 goes after 40
        ];

        let low_leaf_witnesses: [MembershipWitness<4>; 4] = [
            create_membership_witness(tree, 1), 
            create_membership_witness(tree, 1), 
            create_membership_witness(tree, 3),
            create_membership_witness(tree, 3),
        ];

        // get sibling path for subtree insertion at index 4 
        let subtree_index = 4;
        let full_sibling_path = tree.get_sibling_path::<4>(subtree_index);
        let new_subtree_sibling_path: [Field; 2] = [full_sibling_path[2], full_sibling_path[3]];

        // insert at index 4 
        let (new_root, new_next_index) = batch_insert::<Field, TestLeafPreimage, 4, 2, 2, 4>(
            start_root,
            4,
            values_to_insert,
            sorted_values,
            sorted_values_indexes,
            new_subtree_sibling_path,
            low_leaf_preimages,
            low_leaf_witnesses,
            poseidon2_hash,
        );

        let initial_leaves_expected = [10, 20, 30, 40, 25, 26, 45, 55, 0, 0, 0, 0, 0, 0, 0, 0];
        let (_, start_root_expected) = create_tree_with_root(initial_leaves_expected, poseidon2_hash);
        assert(new_root == start_root_expected, "New root should be the same as the expected root");

        // verify next index is updated correctly
        assert(new_next_index == 8, "Next available leaf index should be 8");
    }

    #[test]
    fn test_batch_insert_sequential_prev_leaf() {
        // Test inserting 15, 16, 17 between 10 and 20
        // This tests the sequential prev_leaf logic
        let initial_leaves = [10, 20, 30, 40];
        let (tree, start_root) = create_tree_with_root(initial_leaves, poseidon2_hash);

        // Values to insert: 15, 16, 17
        let values_to_insert: [Field; 4] = [15, 16, 17, 0]; // 0 is empty
        let sorted_values: [Field; 4] = [15, 16, 17, 0];
        let sorted_values_indexes: [u32; 4] = [0, 1, 2, 3];

        // Low leaf preimages: 15 uses low_leaf (10->20), 16 and 17 use prev_leaf
        let low_leaf_preimages: [TestLeafPreimage; 4] = [
            TestLeafPreimage { value: 10, next_value: 20 }, // 15 goes between 10 and 20
            TestLeafPreimage { value: 10, next_value: 20 }, // 16 will use prev_leaf (15)
            TestLeafPreimage { value: 10, next_value: 20 }, // 17 will use prev_leaf (16)
            TestLeafPreimage { value: 0, next_value: 0 },   // empty
        ];

        // Create membership witnesses
        let low_leaf_witnesses: [MembershipWitness<2>; 4] = [
            create_membership_witness(tree, 0), // leaf 10 at index 0
            create_membership_witness(tree, 0), // leaf 10 at index 0 (not used for 16)
            create_membership_witness(tree, 0), // leaf 10 at index 0 (not used for 17)
            create_membership_witness(tree, 0), // dummy
        ];

        // Get sibling path for subtree insertion
        let subtree_index = 4;
        let new_subtree_sibling_path = tree.get_sibling_path::<2>(subtree_index);

        // Insert at index 4
        let (_new_root, new_next_index) = batch_insert::<Field, TestLeafPreimage, 4, 2, 2, 2>(
            start_root,
            4,
            values_to_insert,
            sorted_values,
            sorted_values_indexes,
            new_subtree_sibling_path,
            low_leaf_preimages,
            low_leaf_witnesses,
            poseidon2_hash,
        );

        // Verify next index is updated correctly (3 non-empty values inserted)
        assert(new_next_index == 7, "Next available leaf index should be 7");
    }


    #[test(should_fail_with = "Subtree width must be a power of 2")]
    fn test_batch_insert_invalid_subtree_width() {
        let initial_leaves = [10, 20, 30, 40];
        let (tree, start_root) = create_tree_with_root(initial_leaves, poseidon2_hash);

        let values_to_insert: [Field; 3] = [25, 35, 45]; // Width 3, not power of 2
        let sorted_values: [Field; 3] = [25, 35, 45];
        let sorted_values_indexes: [u32; 3] = [0, 1, 2];

        let low_leaf_preimages: [TestLeafPreimage; 3] = [
            TestLeafPreimage { value: 20, next_value: 30 },
            TestLeafPreimage { value: 20, next_value: 30 },
            TestLeafPreimage { value: 30, next_value: 40 },
        ];

        let low_leaf_witnesses: [MembershipWitness<2>; 3] = [
            create_membership_witness(tree, 1),
            create_membership_witness(tree, 1),
            create_membership_witness(tree, 2),
        ];

        let subtree_index = 4;
        let new_subtree_sibling_path = tree.get_sibling_path::<2>(subtree_index);

        // This should fail because SubtreeWidth=3 is not a power of 2
        let (_new_root, _new_next_index) = batch_insert::<Field, TestLeafPreimage, 3, 2, 2, 2>(
            start_root,
            4,
            values_to_insert,
            sorted_values,
            sorted_values_indexes,
            new_subtree_sibling_path,
            low_leaf_preimages,
            low_leaf_witnesses,
            poseidon2_hash,
        );
    }

    #[test(should_fail_with = "Start next available leaf index must be a multiple of the subtree width")]
    fn test_batch_insert_invalid_alignment() {
        let initial_leaves = [10, 20, 30, 40];
        let (tree, start_root) = create_tree_with_root(initial_leaves, poseidon2_hash);

        let values_to_insert: [Field; 4] = [25, 35, 45, 55];
        let sorted_values: [Field; 4] = [25, 35, 45, 55];
        let sorted_values_indexes: [u32; 4] = [0, 1, 2, 3];

        let low_leaf_preimages: [TestLeafPreimage; 4] = [
            TestLeafPreimage { value: 20, next_value: 30 },
            TestLeafPreimage { value: 20, next_value: 30 },
            TestLeafPreimage { value: 30, next_value: 40 },
            TestLeafPreimage { value: 40, next_value: 0 },
        ];

        let low_leaf_witnesses: [MembershipWitness<2>; 4] = [
            create_membership_witness(tree, 1),
            create_membership_witness(tree, 1),
            create_membership_witness(tree, 2),
            create_membership_witness(tree, 3),
        ];

        let subtree_index = 2; // Index 2, not aligned to SubtreeWidth=4
        let new_subtree_sibling_path = tree.get_sibling_path::<2>(subtree_index);

        // This should fail because index 2 is not a multiple of 4
        let (_new_root, _new_next_index) = batch_insert::<Field, TestLeafPreimage, 4, 2, 2, 2>(
            start_root,
            2,
            values_to_insert,
            sorted_values,
            sorted_values_indexes,
            new_subtree_sibling_path,
            low_leaf_preimages,
            low_leaf_witnesses,
            poseidon2_hash,
        );
    }

}
