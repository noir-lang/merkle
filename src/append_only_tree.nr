use crate::membership::assert_check_membership;
use crate::root::calculate_empty_tree_root;
use crate::root::compute_root_from_sibling_path;
use std::hash::Hasher;

pub fn insert_leaf_to_snapshot_tree<let TreeHeight: u32, H>(
    current_root: Field,
    next_available_leaf_index: u64,
    sibling_path: [Field; TreeHeight],
    leaf_to_insert: Field,
) -> (Field, u64)
where
    H: Hasher + Default,
{
    insert_subtree_to_snapshot_tree::<TreeHeight, 0, H>(
        current_root,
        next_available_leaf_index,
        sibling_path,
        leaf_to_insert,
    )
}

pub fn insert_subtree_to_snapshot_tree<let TreeHeight: u32, let SubtreeHeight: u32, H>(
    current_root: Field,
    next_available_leaf_index: u64,
    sibling_path: [Field; TreeHeight - SubtreeHeight],
    subtree_root_to_insert: Field,
) -> (Field, u64)
where
    H: Hasher + Default,
{
    assert(SubtreeHeight < TreeHeight, "Subtree depth must be less than tree height");
    assert(
        next_available_leaf_index % (SubtreeHeight + 1) as u64 == 0,
        "Next available leaf index not valid",
    );
    let leaf_index_at_depth = (next_available_leaf_index >> (SubtreeHeight as u64)) as u32;

    let empty_subtree_root = calculate_empty_tree_root::<H>(SubtreeHeight);

    // Check that the current root is correct and that there is an empty subtree at the insertion location
    assert_check_membership::<TreeHeight - SubtreeHeight, H>(
        empty_subtree_root,
        leaf_index_at_depth as Field,
        sibling_path,
        current_root,
    );

    // if index of leaf is x, index of its parent is x/2 or x >> 1. We need to find the parent `SubtreeHeight` levels up.
    let new_root = compute_root_from_sibling_path::<TreeHeight - SubtreeHeight, H>(
        subtree_root_to_insert,
        leaf_index_at_depth as Field,
        sibling_path,
    );

    // 2^SubtreeHeight is the number of leaves added. 2^x = 1 << x
    let new_next_available_leaf_index = next_available_leaf_index + (1 << (SubtreeHeight as u64));

    (new_root, new_next_available_leaf_index)
}

pub mod tests {
    use crate::append_only_tree::{insert_leaf_to_snapshot_tree, insert_subtree_to_snapshot_tree};
    use crate::merkle_tree::MerkleTree;
    use crate::root::calculate_empty_tree_root;
    use crate::utils::poseidon2_hash;
    use poseidon::poseidon2::Poseidon2Hasher;

    /// build a partialtree with the first `num_filled` leaves set to values, rest are zeros
    fn build_partial_tree<let N: u32>(
        leaves: [Field; N],
        num_filled: u32,
    ) -> MerkleTree<N, Poseidon2Hasher> {
        let mut arr = [0; N];
        for i in 0..num_filled {
            arr[i] = leaves[i];
        }
        MerkleTree::<N, Poseidon2Hasher>::new(arr)
    }

    /// Get sibling path of a subtree root in the tree
    ///
    /// Given a subtree at depth `SubtreeHeight`, this function returns the sibling path
    /// from that subtree root to the tree root.
    fn get_subtree_root_sibling_path<let NumLeaves: u32, let TreeHeight: u32, let SubtreeHeight: u32>(
        leaves: [Field; NumLeaves],
        num_filled: u32,
        leaf_index: u32,
    ) -> [Field; TreeHeight - SubtreeHeight] {
        let tree = build_partial_tree::<NumLeaves>(leaves, num_filled);
        let full_path = tree.get_sibling_path::<TreeHeight>(leaf_index);

        // last (TreeHeight - SubtreeHeight) elements
        let path_length = TreeHeight - SubtreeHeight;
        let mut path = [0; TreeHeight - SubtreeHeight];
        for i in 0..path_length {
            path[i] = full_path[SubtreeHeight + i];
        }
        path
    }

    /// Insert a leaf and verify the result matches expected tree state
    fn insert_leaf_and_verify<let NumLeaves: u32, let TreeHeight: u32>(
        current_root: Field,
        next_index: u64,
        leaves: [Field; NumLeaves],
        leaf_index: u32,
        leaf_to_insert: Field,
    ) -> (Field, u64) {
        let sibling_path = get_subtree_root_sibling_path::<NumLeaves, TreeHeight, 0>(
            leaves,
            next_index as u32,
            leaf_index,
        );
        let (new_root, new_next_index) = insert_leaf_to_snapshot_tree::<TreeHeight, Poseidon2Hasher>(
            current_root,
            next_index,
            sibling_path,
            leaf_to_insert,
        );

        // Verify root matches expected tree (inserting a leaf adds 1)
        let expected_num_filled = (next_index + 1) as u32;
        let expected_tree = build_partial_tree::<NumLeaves>(leaves, expected_num_filled);
        let expected_root = expected_tree.get_root();
        assert_eq(new_root, expected_root);
        assert_eq(new_next_index, expected_num_filled as u64);

        (new_root, new_next_index)
    }

    /// Insert a subtree and verify the result matches expected tree state
    fn insert_subtree_and_verify<let NumLeaves: u32, let TreeHeight: u32, let SubtreeHeight: u32>(
        current_root: Field,
        next_index: u64,
        leaves: [Field; NumLeaves],
        leaf_index: u32,
        subtree_root: Field,
    ) -> (Field, u64) {
        let sibling_path = get_subtree_root_sibling_path::<NumLeaves, TreeHeight, SubtreeHeight>(
            leaves,
            next_index as u32,
            leaf_index,
        );
        let (new_root, new_next_index) = insert_subtree_to_snapshot_tree::<TreeHeight, SubtreeHeight, Poseidon2Hasher>(
            current_root,
            next_index,
            sibling_path,
            subtree_root,
        );

        // Verify root matches expected tree (inserting a subtree of depth SubtreeHeight adds 2^SubtreeHeight leaves)
        let expected_num_filled = (next_index + (1 << (SubtreeHeight as u64))) as u32;
        let expected_tree = build_partial_tree::<NumLeaves>(leaves, expected_num_filled);
        let expected_root = expected_tree.get_root();
        assert_eq(new_root, expected_root);
        assert_eq(new_next_index, expected_num_filled as u64);

        (new_root, new_next_index)
    }

    #[test]
    fn test_insert_first_leaf() {
        // insert first leaf into empty tree (height 2, 4 leaves)
        let tree_height: u32 = 2;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let leaves = [42, 0, 0, 0];

        let (_, _) = insert_leaf_and_verify::<4, 2>(empty_root, 0, leaves, 0, leaves[0]);
    }

    #[test]
    fn test_insert_second_leaf() {
        // insert second leaf after first
        let leaves = [10, 20, 0, 0];
        let tree_after_first = build_partial_tree::<4>(leaves, 1);
        let root_after_first = tree_after_first.get_root();

        let (_, _) =
            insert_leaf_and_verify::<4, 2>(root_after_first, 1, leaves, 1, leaves[1]);
    }

    #[test]
    fn test_sequential_leaf_insertions() {
        // insert 4 leaves sequentially
        let tree_height: u32 = 2;
        let leaves = [100, 200, 300, 400];
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);

        let mut current_root = empty_root;
        let mut next_index: u64 = 0;

        for i in 0..4 {
            let (new_root, new_next_index) = insert_leaf_and_verify::<4, 2>(
                current_root,
                next_index,
                leaves,
                i as u32,
                leaves[i],
            );
            current_root = new_root;
            next_index = new_next_index;
        }
    }

    #[test]
    fn test_insert_subtree_depth_1() {
        // insert a subtree of depth 1 (2 leaves)
        let tree_height: u32 = 2;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let subtree_leaf1 = 50;
        let subtree_leaf2 = 60;
        let subtree_root = poseidon2_hash(subtree_leaf1, subtree_leaf2);
        let leaves = [subtree_leaf1, subtree_leaf2, 0, 0];

        let (_, _) = insert_subtree_and_verify::<4, 2, 1>(
            empty_root,
            0,
            leaves,
            0,
            subtree_root,
        );
    }

    // Testing that inserting a subtree with 2 leaves after inserting 1 leaf is invalid because
    // subtree with 2 leaves cannot not be inserted at leaf index 1
    #[test(should_fail_with = "Next available leaf index not valid")]
    fn test_insert_subtree_after_leaves_invalid() {
        // Insert a single leaf, then insert a subtree
        let tree_height: u32 = 2;
        let leaves = [10, 20, 30, 0];
        let subtree_root = poseidon2_hash(leaves[1], leaves[2]);

        // First insert a leaf
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let (root_after_first, next_after_first) =
            insert_leaf_and_verify::<4, 2>(empty_root, 0, leaves, 0, leaves[0]);

        // Then insert a subtree with 2 leaves at position 1
        let (_, _) = insert_subtree_and_verify::<4, 2, 1>(
            root_after_first,
            next_after_first,
            leaves,
            1,
            subtree_root,
        );
    }

    // same as above except the subtree is inserted at index 2 instead of 1
    #[test]
    fn test_insert_subtree_after_leaves() {
        // Insert a single leaf, then insert a subtree
        let tree_height: u32 = 2;
        let leaves = [10, 0, 20, 30];
        let subtree_root = poseidon2_hash(leaves[2], leaves[3]);

        // First insert a leaf
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let (root_after_first, next_after_first) =
            insert_leaf_and_verify::<4, 2>(empty_root, 0, leaves, 0, leaves[0]);

        // Then insert a subtree with 2 leaves at position 1
        let (_, _) = insert_subtree_and_verify::<4, 2, 1>(
            root_after_first,
            next_after_first + 1,
            leaves,
            2,
            subtree_root,
        );
    }

    #[test]
    fn test_insert_two_trees_then_leaf() {
        // Tree with height 3, 8 leaves, first insert subtree depth 2, then subtree depth 1, then leaf
        let tree_height: u32 = 3;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);

        // Insert subtree depth 2 (4 leaves)
        let leaves1 = [4, 5, 6, 7, 0, 0, 0, 0];
        let subtree_root1 = poseidon2_hash(poseidon2_hash(4, 5), poseidon2_hash(6, 7));
        let (root1, next1) =
            insert_subtree_and_verify::<8, 3, 2>(empty_root, 0, leaves1, 0, subtree_root1);

        // Insert subtree depth 1 (2 leaves)
        let leaves2 = [4, 5, 6, 7, 2, 3, 0, 0];
        let subtree_root2 = poseidon2_hash(2, 3);
        let (root2, next2) =
            insert_subtree_and_verify::<8, 3, 1>(root1, next1, leaves2, 4, subtree_root2);

        // Insert leaf
        let leaves3 = [4, 5, 6, 7, 2, 3, 1, 0];
        let (_, _) = insert_leaf_and_verify::<8, 3>(root2, next2, leaves3, 6, 1);
    }
}
