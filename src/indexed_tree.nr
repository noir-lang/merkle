pub mod check_valid_low_leaf;

use crate::leaf_preimage::{IndexedTreeLeafPreimage, IndexedTreeLeafValue};
use crate::membership::{assert_check_membership, MembershipWitness};
use crate::root::{calculate_empty_tree_root, compute_root_from_sibling_path};
use crate::utils::create_tree_with_root;
use dep::check_shuffle::{check_shuffle, get_shuffle_indices};
use std::hash::Hasher;
pub fn batch_insert<Value, Leaf, let SubtreeWidth: u32, let SiblingPathLength: u32, let SubtreeHeight: u32, let TreeHeight: u32, H>(
    start_root: Field,
    start_next_available_leaf_index: u64,
    values_to_insert: [Value; SubtreeWidth],
    sorted_values: [Value; SubtreeWidth],
    new_subtree_sibling_path: [Field; SiblingPathLength],
    low_leaf_preimages: [Leaf; SubtreeWidth],
    low_leaf_membership_witnesses: [MembershipWitness<TreeHeight>; SubtreeWidth],
) -> (Field, u64)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
    H: Hasher + Default,
{
    // A permutation to the values is provided to make the insertion use only one insertion strategy
    // However, for the actual insertion in the tree the original order is respected, the sorting is only used for validation of the links
    // and low leaf updates.

    check_shuffle(values_to_insert, sorted_values);
    let sorted_values_indexes = get_shuffle_indices(values_to_insert, sorted_values);

    // Now, update the existing leaves with the new leaves
    let mut current_tree_root = start_root;
    let mut insertion_subtree = [Leaf::empty(); SubtreeWidth];
    let start_insertion_index = start_next_available_leaf_index;

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

            assert(is_update | is_in_range, "Invalid low leaf");

            // perform membership check for the low leaf against the original root
            assert_check_membership::<TreeHeight, H>(
                low_leaf_preimage.as_leaf(),
                witness.leaf_index,
                witness.sibling_path,
                current_tree_root,
            );

            let value_index = sorted_values_indexes[i];

            // Calculate the new value of the low_leaf
            let updated_low_leaf = if is_update {
                low_leaf_preimage.update_value(value)
            } else {
                low_leaf_preimage.update_pointers(
                    value_key,
                    start_insertion_index as u32 + value_index,
                )
            };

            current_tree_root = compute_root_from_sibling_path::<TreeHeight, H>(
                updated_low_leaf.as_leaf(),
                witness.leaf_index,
                witness.sibling_path,
            );

            insertion_subtree[value_index] = if is_update {
                Leaf::empty()
            } else {
                Leaf::build_insertion_leaf(value, low_leaf_preimage)
            };
        }
    }

    let empty_subtree_root = calculate_empty_tree_root::<H>(SubtreeHeight);
    let leaf_index_subtree_depth = (start_insertion_index >> (SubtreeHeight as u64)) as u32;

    assert_check_membership::<SiblingPathLength, H>(
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
    let subtree_index = (start_insertion_index >> (SubtreeHeight as u64)) as u32;
    let new_root = compute_root_from_sibling_path::<SiblingPathLength, H>(
        subtree_root,
        subtree_index as Field,
        new_subtree_sibling_path,
    );

    (new_root, start_insertion_index + (values_to_insert.len() as u64))
}

pub fn insert<Value, Leaf, let TreeHeight: u32, H>(
    mut current_root: Field,
    mut next_available_leaf_index: u64,
    value: Value,
    low_leaf_preimage: Leaf,
    low_leaf_membership_witness: MembershipWitness<TreeHeight>,
    insertion_sibling_path: [Field; TreeHeight],
) -> (Field, u64)
where
    Value: IndexedTreeLeafValue,
    Leaf: IndexedTreeLeafPreimage<Value>,
    H: Hasher + Default,
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
    assert_check_membership::<TreeHeight, H>(
        low_leaf_preimage.as_leaf(),
        low_leaf_membership_witness.leaf_index,
        low_leaf_membership_witness.sibling_path,
        current_root,
    );

    // Calculate the new value of the low_leaf
    let updated_low_leaf = if is_update {
        low_leaf_preimage.update_value(value)
    } else {
        low_leaf_preimage.update_pointers(value_key, next_available_leaf_index as u32)
    };

    // Update low leaf
    current_root = compute_root_from_sibling_path::<TreeHeight, H>(
        updated_low_leaf.as_leaf(),
        low_leaf_membership_witness.leaf_index,
        low_leaf_membership_witness.sibling_path,
    );

    if is_update {
        // If it's an update, we don't need to insert the new leaf and advance the tree
        (current_root, next_available_leaf_index)
    } else {
        let insertion_leaf = Leaf::build_insertion_leaf(value, low_leaf_preimage);
        assert_check_membership::<TreeHeight, H>(
            0,
            next_available_leaf_index as Field,
            insertion_sibling_path,
            current_root,
        );

        // Calculate the new root
        current_root = compute_root_from_sibling_path::<TreeHeight, H>(
            insertion_leaf.as_leaf(),
            next_available_leaf_index as Field,
            insertion_sibling_path,
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
        utils::{create_membership_witness, create_tree_with_root},
    };
    use poseidon::poseidon2::Poseidon2Hasher;
    use std::hash::pedersen_hash;

    struct TestLeafPreimage {
        value: Field,
        next_value: Field,
    }

    impl LeafPreimage for TestLeafPreimage {
        fn get_key(self) -> Field {
            self.value
        }

        fn as_leaf(self) -> Field {
            pedersen_hash([self.value, self.next_value])
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
        // tree leaves: [10, 20, 30, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        let initial_leaves_preimages = [
            TestLeafPreimage { value: 10, next_value: 20 },
            TestLeafPreimage { value: 20, next_value: 30 },
            TestLeafPreimage { value: 30, next_value: 40 },
            TestLeafPreimage { value: 40, next_value: 0 },
        ];
        let leaves_serialized =
            initial_leaves_preimages.map(|leaf: TestLeafPreimage| leaf.as_leaf());
        let remaining_leaves = [0; 12];
        let initial_leaves: [Field; 16] = leaves_serialized.concat(remaining_leaves);
        let (tree, start_root) = create_tree_with_root::<16, Poseidon2Hasher>(initial_leaves);

        // Values to insert: 25, 35, 45, 55
        let values_to_insert: [Field; 4] = [25, 26, 45, 55];
        let sorted_values: [Field; 4] = [25, 26, 45, 55];
        let sorted_values_indexes: [u32; 4] = [0, 1, 2, 3];

        let preimage_20_30 = TestLeafPreimage { value: 20, next_value: 30 };
        let preimage_40_0 = TestLeafPreimage { value: 40, next_value: 0 };

        let low_leaf_preimages: [TestLeafPreimage; 4] = [
            preimage_20_30, // 25 goes between 20 and 30
            preimage_20_30, // 26 goes between 20 and 30
            preimage_40_0, // 45 goes after 40
            preimage_40_0, // 55 goes after 40
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
        let (new_root, new_next_index) = batch_insert::<Field, TestLeafPreimage, 4, 2, 2, 4, Poseidon2Hasher>(
            start_root,
            4,
            values_to_insert,
            sorted_values,
            sorted_values_indexes,
            new_subtree_sibling_path,
            low_leaf_preimages,
            low_leaf_witnesses,
        );

        //expected tree leaves: [10, 20, 30, 40, 25, 26, 45, 55, 0, 0, 0, 0, 0, 0, 0, 0];
        let initial_leaves_expected_preimages = [
            TestLeafPreimage { value: 10, next_value: 20 },
            TestLeafPreimage { value: 20, next_value: 25 },
            TestLeafPreimage { value: 30, next_value: 40 },
            TestLeafPreimage { value: 40, next_value: 45 },
            TestLeafPreimage { value: 25, next_value: 26 },
            TestLeafPreimage { value: 26, next_value: 30 },
            TestLeafPreimage { value: 45, next_value: 55 },
            TestLeafPreimage { value: 55, next_value: 0 },
        ];

        let leaves_expected_serialized =
            initial_leaves_expected_preimages.map(|leaf: TestLeafPreimage| leaf.as_leaf());
        let remaining_leaves_expected = [0; 8];
        let initial_leaves_expected: [Field; 16] =
            leaves_expected_serialized.concat(remaining_leaves_expected);
        let (_, start_root_expected) =
            create_tree_with_root::<16, Poseidon2Hasher>(initial_leaves_expected);
        assert(new_root == start_root_expected, "New root should be the same as the expected root");

        // verify next index is updated correctly
        assert(new_next_index == 8, "Next available leaf index should be 8");
    }

}
