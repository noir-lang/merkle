use crate::membership::assert_check_membership;
use crate::root::compute_root_from_sibling_path;
use std::hash::Hasher;
use crate::root::calculate_empty_tree_root;

pub fn insert_leaf_to_snapshot_tree<let TreeHeight: u32, H>(
    current_root: Field,
    next_available_leaf_index: u64,
    sibling_path: [Field; TreeHeight],
    leaf_to_insert: Field,
) -> (Field, u64)
where
    H: Hasher + Default,
{
    insert_subtree_to_snapshot_tree::<TreeHeight, H>(
        current_root,
        next_available_leaf_index,
        sibling_path,
        leaf_to_insert,
        0,
    )
}

pub fn insert_subtree_to_snapshot_tree<let TreeHeight: u32, H>(
    current_root: Field,
    next_available_leaf_index: u64,
    sibling_path: [Field; TreeHeight],
    subtree_root_to_insert: Field,
    subtree_depth: u32,
) -> (Field, u64)
where
    H: Hasher + Default,
{
    assert(subtree_depth < TreeHeight, "Subtree depth must be less than tree height");
    let leaf_index_at_depth = (next_available_leaf_index >> (subtree_depth as u64)) as u32;

    let empty_subtree_root = calculate_empty_tree_root::<H>(subtree_depth);

    // Check that the current root is correct and that there is an empty subtree at the insertion location
    assert_check_membership::<TreeHeight, H>(
        empty_subtree_root,
        leaf_index_at_depth as Field,
        sibling_path,
        current_root,
    );

    // if index of leaf is x, index of its parent is x/2 or x >> 1. We need to find the parent `subtree_depth` levels up.
    let new_root = compute_root_from_sibling_path::<TreeHeight, H>(
        subtree_root_to_insert,
        leaf_index_at_depth as Field,
        sibling_path,
    );

    // 2^subtree_depth is the number of leaves added. 2^x = 1 << x
    let new_next_available_leaf_index = next_available_leaf_index + (1 << (subtree_depth as u64));

    (new_root, new_next_available_leaf_index)
}

pub mod tests {
    use crate::append_only_tree::{insert_leaf_to_snapshot_tree, insert_subtree_to_snapshot_tree};
    use crate::merkle_tree::MerkleTree;
    use crate::root::calculate_empty_tree_root;
    use crate::utils::poseidon2_hash;
    use poseidon::poseidon2::Poseidon2Hasher;

    /// Helper to get sibling path of any internal node from an empty tree
    fn get_empty_tree_sibling_path<let N: u32, let K: u32>() -> [Field; K] {
        let empty_tree = MerkleTree::<N, Poseidon2Hasher>::empty();
        empty_tree.get_sibling_path::<K>(0)
    }

    /// build a partialtree with the first `num_filled` leaves set to values, rest are zeros
    fn build_partial_tree<let N: u32>(leaves: [Field; N], num_filled: u32) -> MerkleTree<N, Poseidon2Hasher> {
        let mut arr = [0; N];
        for i in 0..num_filled {
            arr[i] = leaves[i];
        }
        MerkleTree::<N, Poseidon2Hasher>::new(arr)
    }

    /// Get sibling path from current tree state at given leaf index
    fn get_sibling_path_from_state<let N: u32, let K: u32>(
        leaves: [Field; N],
        num_filled: u32,
        leaf_index: u32,
    ) -> [Field; K] {
        let tree = build_partial_tree::<N>(leaves, num_filled);
        tree.get_sibling_path::<K>(leaf_index)
    }

    /// Insert a leaf and verify the result matches expected tree state
    fn insert_leaf_and_verify<let N: u32, let K: u32>(
        current_root: Field,
        next_index: u64,
        leaves: [Field; N],
        num_filled: u32,
        leaf_index: u32,
        leaf_to_insert: Field,
        expected_num_filled: u32,
    ) -> (Field, u64) {
        let sibling_path = get_sibling_path_from_state::<N, K>(leaves, num_filled, leaf_index);
        let (new_root, new_next_index) = insert_leaf_to_snapshot_tree::<K, Poseidon2Hasher>(
            current_root,
            next_index,
            sibling_path,
            leaf_to_insert,
        );

        // Verify root matches expected tree
        let expected_tree = build_partial_tree::<N>(leaves, expected_num_filled);
        let expected_root = expected_tree.get_root();
        assert_eq(new_root, expected_root);
        assert_eq(new_next_index, expected_num_filled as u64);

        (new_root, new_next_index)
    }

    /// Insert a subtree and verify the result matches expected tree state
    fn insert_subtree_and_verify<let N: u32, let K: u32>(
        current_root: Field,
        next_index: u64,
        leaves: [Field; N],
        num_filled: u32,
        leaf_index: u32,
        subtree_root: Field,
        subtree_depth: u32,
        expected_num_filled: u32,
    ) -> (Field, u64) {
        let sibling_path = get_sibling_path_from_state::<N, K>(leaves, num_filled, leaf_index);
        let (new_root, new_next_index) = insert_subtree_to_snapshot_tree::<K, Poseidon2Hasher>(
            current_root,
            next_index,
            sibling_path,
            subtree_root,
            subtree_depth,
        );

        // Verify root matches expected tree
        let expected_tree = build_partial_tree::<N>(leaves, expected_num_filled);
        let expected_root = expected_tree.get_root();
        assert_eq(new_root, expected_root);
        assert_eq(new_next_index, expected_num_filled as u64);

        (new_root, new_next_index)
    }

    #[test]
    fn test_insert_first_leaf() {
        // Insert first leaf into empty tree (height 2, 4 leaves)
        let tree_height: u32 = 2;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let leaves = [42, 0, 0, 0];

        let (_, _) = insert_leaf_and_verify::<4, 2>(
            empty_root,
            0,
            leaves,
            0,
            0,
            leaves[0],
            1,
        );
    }

    #[test]
    fn test_insert_second_leaf() {
        // Insert second leaf after first
        let leaves = [10, 20, 0, 0];
        let tree_after_first = build_partial_tree::<4>(leaves, 1);
        let root_after_first = tree_after_first.get_root();

        let (_, _) = insert_leaf_and_verify::<4, 2>(
            root_after_first,
            1,
            leaves,
            1,
            1,
            leaves[1],
            2,
        );
    }

    #[test]
    fn test_sequential_leaf_insertions() {
        // Insert 4 leaves sequentially
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
                i,
                i as u32,
                leaves[i],
                i + 1,
            );
            current_root = new_root;
            next_index = new_next_index;
        }
    }

    #[test]
    fn test_insert_subtree_depth_1() {
        // Insert a subtree of depth 1 (2 leaves) at once
        let tree_height: u32 = 2;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let subtree_leaf1 = 50;
        let subtree_leaf2 = 60;
        let subtree_root = poseidon2_hash(subtree_leaf1, subtree_leaf2);
        let leaves = [subtree_leaf1, subtree_leaf2, 0, 0];

        let (_, _) = insert_subtree_and_verify::<4, 2>(
            empty_root,
            0,
            leaves,
            0,
            0,
            subtree_root,
            1, // subtree_depth = 1 (2 leaves)
            2,
        );
    }

    #[test]
    fn test_insert_subtree_after_leaves() {
        // Insert a single leaf, then insert a subtree
        let tree_height: u32 = 2;
        let leaves = [10, 20, 30, 0];
        let subtree_root = poseidon2_hash(leaves[1], leaves[2]);

        // First insert a leaf
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let (root_after_first, next_after_first) = insert_leaf_and_verify::<4, 2>(
            empty_root,
            0,
            leaves,
            0,
            0,
            leaves[0],
            1,
        );

        // Then insert a subtree at position 1
        let (_, _) = insert_subtree_and_verify::<4, 2>(
            root_after_first,
            next_after_first,
            leaves,
            1,
            1,
            subtree_root,
            1, // subtree_depth = 1
            3,
        );
    }

    #[test]
    fn test_insert_leaf_then_subtree_then_leaf() {
        // Complex sequence: leaf -> subtree -> leaf
        let tree_height: u32 = 2;
        let leaves = [1, 2, 3, 4];
        let subtree_root = poseidon2_hash(leaves[1], leaves[2]);

        let mut current_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);
        let mut next_index: u64 = 0;

        // Insert first leaf
        let (root1, next1) = insert_leaf_and_verify::<4, 2>(
            current_root,
            next_index,
            leaves,
            0,
            0,
            leaves[0],
            1,
        );
        current_root = root1;
        next_index = next1;

        // Insert subtree
        let (root2, next2) = insert_subtree_and_verify::<4, 2>(
            current_root,
            next_index,
            leaves,
            1,
            1,
            subtree_root,
            1,
            3,
        );
        current_root = root2;
        next_index = next2;

        // Insert second leaf
        let (_, _) = insert_leaf_and_verify::<4, 2>(
            current_root,
            next_index,
            leaves,
            3,
            3,
            leaves[3],
            4,
        );
    }

    #[test]
    fn test_larger_tree_height_3() {
        // Test with tree height 3 (8 leaves)
        let tree_height: u32 = 3;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);

        // Insert first 3 leaves sequentially
        let leaves = [10, 20, 30, 0, 0, 0, 0, 0];
        let mut current_root = empty_root;
        let mut next_index: u64 = 0;

        for i in 0..3 {
            let (new_root, new_next_index) = insert_leaf_and_verify::<8, 3>(
                current_root,
                next_index,
                leaves,
                i,
                i as u32,
                leaves[i],
                i + 1,
            );
            current_root = new_root;
            next_index = new_next_index;
        }
    }

    #[test]
    fn test_next_index_calculation() {
        // Verify next_index is correctly updated for different subtree depths
        let tree_height: u32 = 3;
        let empty_root = calculate_empty_tree_root::<Poseidon2Hasher>(tree_height);

        // Insert leaf (depth 0) - should add 1
        let leaves1 = [1, 0, 0, 0, 0, 0, 0, 0];
        let sibling_path0 = get_empty_tree_sibling_path::<8, 3>(0);
        let (root1, next1) = insert_leaf_to_snapshot_tree::<3, Poseidon2Hasher>(
            empty_root,
            0,
            sibling_path0,
            1,
        );
        assert_eq(next1, 1);
        assert_eq(root1, build_partial_tree::<8>(leaves1, 1).get_root());

        // Insert subtree depth 1 (2 leaves) - should add 2
        let leaves2 = [1, 2, 3, 0, 0, 0, 0, 0];
        let subtree_root = poseidon2_hash(2, 3);
        let (root2, next2) = insert_subtree_and_verify::<8, 3>(
            root1,
            next1,
            leaves2,
            1,
            1,
            subtree_root,
            1,
            3,
        );
        assert_eq(next2, 3); // 1 + 2 = 3

        // Insert subtree depth 2 (4 leaves) - should add 4
        let leaves3 = [1, 2, 3, 4, 5, 6, 7, 0];
        let subtree_root2 = poseidon2_hash(poseidon2_hash(4, 5), poseidon2_hash(6, 7));
        let (_, next3) = insert_subtree_and_verify::<8, 3>(
            root2,
            next2,
            leaves3,
            3,
            2,
            subtree_root2,
            2,
            7,
        );
        assert_eq(next3, 7); // 3 + 4 = 7
    }
}
