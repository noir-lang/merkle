use crate::merkle_tree::hash_nodes;
use crate::merkle_tree::MerkleTree;
use crate::utils::create_tree_with_root;
use poseidon::poseidon2::Poseidon2Hasher;
use std::hash::Hasher;

// Calculate the Merkle tree root from the sibling path and leaf.
//
// The leaf is hashed with its sibling, and then the result is hashed
// with the next sibling etc in the path. The last hash is the root.
//
// TODO(David/Someone): The cpp code is using a uint256, whereas its
// TODO a bit simpler in Noir to just have a bit array.
// TODO: I'd generally like to avoid u256 for algorithms like
// this because it means we never even need to consider cases where
// the index is greater than p.
pub fn compute_root_from_sibling_path<let N: u32, H>(
    leaf: Field,
    leaf_index: Field,
    sibling_path: [Field; N],
) -> Field
where
    H: Hasher + Default,
{
    let mut node = leaf;
    let indices: [bool; N] = leaf_index.to_le_bits();

    for i in 0..N {
        let (hash_left, hash_right) = if indices[i] {
            (sibling_path[i], node)
        } else {
            (node, sibling_path[i])
        };
        node = hash_nodes::<H>(hash_left, hash_right);
    }
    node
}

/// Calculate the root of an empty Merkle tree (filled with zeros) for any hash function
///
/// This function computes the root of a complete binary tree of given depth where all leaves are zero.
/// For depth d, the tree has 2^d leaves, all set to 0.
pub fn calculate_empty_tree_root<H>(depth: u32) -> Field
where
    H: Hasher + Default,
{
    assert(depth < 11, "Depth must be between 0 and 10");
    let mut current_value = 0;
    for i in 1..11 {
        // Build the tree bottom-up by hashing pairs
        let new_value = hash_nodes::<H>(current_value, current_value);
        if i <= depth {
            current_value = new_value;
        }
    }
    current_value
}

// These values are precomputed and we run tests to ensure that they
// are correct. The values themselves were computed from the cpp code.
//
// Would be good if we could use width since the compute_subtree
// algorithm uses depth.
pub fn calculate_empty_tree_root_poseidon(depth: u32) -> Field {
    if depth == 0 {
        0
    } else if depth == 1 {
        0x0b63a53787021a4a962a452c2921b3663aff1ffd8d5510540f8e659e782956f1
    } else if depth == 2 {
        0x0e34ac2c09f45a503d2908bcb12f1cbae5fa4065759c88d501c097506a8b2290
    } else if depth == 3 {
        0x21f9172d72fdcdafc312eee05cf5092980dda821da5b760a9fb8dbdf607c8a20
    } else if depth == 4 {
        0x2373ea368857ec7af97e7b470d705848e2bf93ed7bef142a490f2119bcf82d8e
    } else if depth == 5 {
        0x120157cfaaa49ce3da30f8b47879114977c24b266d58b0ac18b325d878aafddf
    } else if depth == 6 {
        0x01c28fe1059ae0237b72334700697bdf465e03df03986fe05200cadeda66bd76
    } else if depth == 7 {
        0x2d78ed82f93b61ba718b17c2dfe5b52375b4d37cbbed6f1fc98b47614b0cf21b
    } else if depth == 8 {
        0x067243231eddf4222f3911defbba7705aff06ed45960b27f6f91319196ef97e1
    } else if depth == 9 {
        0x1849b85f3c693693e732dfc4577217acc18295193bede09ce8b97ad910310972
    } else if depth == 10 {
        0x2a775ea761d20435b31fa2c33ff07663e24542ffb9e7b293dfce3042eb104686
    } else {
        panic(f"depth should be between 0 and 10")
    }
}

#[test]
fn test_calculate_empty_tree_root() {
    for depth in 0..11 {
        assert(
            calculate_empty_tree_root::<Poseidon2Hasher>(depth)
                == calculate_empty_tree_root_poseidon(depth),
        );
    }
}

#[test]
fn test_merkle_root_interop_test() {
    // This is a test to ensure that we match the cpp implementation.
    // You can grep for `TEST_F(root_rollup_tests, noir_interop_test)`
    // to find the test that matches this.
    let (_, root) = create_tree_with_root::<16, Poseidon2Hasher>([
        1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4, 1, 2, 3, 4,
    ]);
    assert(0x1a09d935ae110b4c861fcec8f9099ec30b4485022aeb3d3cf9d7168e38fdc231 == root);

    let (_, empty_root) = create_tree_with_root::<16, Poseidon2Hasher>([0; 16]);
    assert(0x2373ea368857ec7af97e7b470d705848e2bf93ed7bef142a490f2119bcf82d8e == empty_root);
}

#[test]
fn test_empty_subroot() {
    assert(calculate_empty_tree_root_poseidon(0) == 0);

    let (_, expected_empty_root_2) = create_tree_with_root::<2, Poseidon2Hasher>([0; 2]);
    assert(calculate_empty_tree_root_poseidon(1) == expected_empty_root_2);

    let (_, expected_empty_root_4) = create_tree_with_root::<4, Poseidon2Hasher>([0; 4]);
    assert(calculate_empty_tree_root_poseidon(2) == expected_empty_root_4);

    let (_, expected_empty_root_8) = create_tree_with_root::<8, Poseidon2Hasher>([0; 8]);
    assert(calculate_empty_tree_root_poseidon(3) == expected_empty_root_8);

    let (_, expected_empty_root_16) = create_tree_with_root::<16, Poseidon2Hasher>([0; 16]);
    assert(calculate_empty_tree_root_poseidon(4) == expected_empty_root_16);

    let (_, expected_empty_root_32) = create_tree_with_root::<32, Poseidon2Hasher>([0; 32]);
    assert(calculate_empty_tree_root_poseidon(5) == expected_empty_root_32);

    let (_, expected_empty_root_64) = create_tree_with_root::<64, Poseidon2Hasher>([0; 64]);
    assert(calculate_empty_tree_root_poseidon(6) == expected_empty_root_64);

    let (_, expected_empty_root_128) = create_tree_with_root::<128, Poseidon2Hasher>([0; 128]);
    assert(calculate_empty_tree_root_poseidon(7) == expected_empty_root_128);

    let (_, expected_empty_root_256) = create_tree_with_root::<256, Poseidon2Hasher>([0; 256]);
    assert(calculate_empty_tree_root_poseidon(8) == expected_empty_root_256);

    let (_, expected_empty_root_512) = create_tree_with_root::<512, Poseidon2Hasher>([0; 512]);
    assert(calculate_empty_tree_root_poseidon(9) == expected_empty_root_512);

    let (_, expected_empty_root_1024) = create_tree_with_root::<1024, Poseidon2Hasher>([0; 1024]);
    assert(calculate_empty_tree_root_poseidon(10) == expected_empty_root_1024);
}

/// helper function to test that compute_root_from_sibling_path correctly reconstructs
/// the root for all leaves in a tree
fn test_compute_root_from_sibling_path_helper<let N: u32, let K: u32>(leaves: [Field; N]) {
    let tree = MerkleTree::<N, Poseidon2Hasher>::new(leaves);
    let root = tree.get_root();

    for i in 0..N {
        let sibling_path = tree.get_sibling_path::<K>(i);
        let computed_root = compute_root_from_sibling_path::<K, Poseidon2Hasher>(
            leaves[i],
            i as Field,
            sibling_path,
        );
        assert_eq(computed_root, root, f"Failed for leaf index {i}");
    }
}

#[test]
fn test_compute_root_from_sibling_path_size_2() {
    // smallest tree: N=2, depth=1
    test_compute_root_from_sibling_path_helper::<2, 1>([1, 2]);
}

#[test]
fn test_compute_root_from_sibling_path_size_16() {
    // N = 16, depth = 4
    test_compute_root_from_sibling_path_helper::<16, 4>([
        10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160,
    ]);
}

#[test]
fn test_compute_root_from_sibling_path_empty_tree_size_4() {
    // empty tree: all zeros
    test_compute_root_from_sibling_path_helper::<4, 2>([0; 4]);
}
