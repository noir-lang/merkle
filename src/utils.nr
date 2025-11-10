use crate::membership::{check_membership, MembershipWitness};
use crate::merkle_tree::MerkleTree;
use std::hash::Hasher;

pub fn check_permutation<T, let N: u32>(
    original_array: [T; N],
    permuted_array: [T; N],
    original_indexes: [u32; N],
)
where
    T: Eq,
{
    let mut seen_value = [false; N];
    for i in 0..N {
        let index = original_indexes[i];
        let original_value = original_array[index];
        assert(permuted_array[i] == original_value, "Invalid index");
        assert(!seen_value[index], "Duplicated index");
        seen_value[index] = true;
    }
}

pub fn poseidon2_hash(left: Field, right: Field) -> Field {
    poseidon::poseidon2::Poseidon2::hash([left, right], 2)
}

/// Create a Merkle tree and return both the tree and its root
pub fn create_tree_with_root<let N: u32, H>(leaves: [Field; N]) -> (MerkleTree<N, H>, Field)
where
    H: Hasher + Default,
{
    let tree = MerkleTree::<N, H>::new(leaves);
    let root = tree.get_root();
    (tree, root)
}

/// Generate a complete membership witness for a leaf
pub fn create_membership_witness<let N: u32, let K: u32, H>(
    tree: MerkleTree<N, H>,
    leaf_index: u32,
) -> MembershipWitness<K>
where
    H: Hasher + Default,
{
    let sibling_path = tree.get_sibling_path::<K>(leaf_index);
    MembershipWitness { leaf_index: leaf_index as Field, sibling_path }
}

/// Verify a leaf exists in a tree using a membership witness
pub fn verify_membership<let K: u32, H>(
    leaf: Field,
    witness: MembershipWitness<K>,
    root: Field,
) -> bool
where
    H: Hasher + Default,
{
    check_membership::<K, H>(leaf, witness.leaf_index, witness.sibling_path, root)
}

/// Create a tree, generate a membership proof, and verify it
pub fn create_and_verify_membership<let N: u32, let K: u32, H>(
    leaves: [Field; N],
    leaf_index: u32,
) -> bool
where
    H: Hasher + Default,
{
    let (tree, root) = create_tree_with_root::<N, H>(leaves);
    let witness = create_membership_witness::<N, K, H>(tree, leaf_index);
    let leaf_value = leaves[leaf_index];
    verify_membership::<K, H>(leaf_value, witness, root)
}

pub mod tests {
    use crate::utils::check_permutation;

    #[test]
    fn test_identity_permutation() {
        // original = permuted
        let original: [Field; 3] = [1, 2, 3];
        let permuted: [Field; 3] = [1, 2, 3];
        let indexes: [u32; 3] = [0, 1, 2];
        check_permutation(original, permuted, indexes);

        //reverse
        let original: [Field; 4] = [10, 20, 30, 40];
        let permuted: [Field; 4] = [40, 30, 20, 10];
        let indexes: [u32; 4] = [3, 2, 1, 0];
        check_permutation(original, permuted, indexes);

        // shuffle
        let original: [Field; 5] = [1, 2, 3, 4, 5];
        let permuted: [Field; 5] = [3, 5, 1, 4, 2];
        let indexes: [u32; 5] = [2, 4, 0, 3, 1];
        check_permutation(original, permuted, indexes);

        // single element
        let original: [Field; 1] = [42];
        let permuted: [Field; 1] = [42];
        let indexes: [u32; 1] = [0];
        check_permutation(original, permuted, indexes);

        // empty array
        let original: [Field; 0] = [];
        let permuted: [Field; 0] = [];
        let indexes: [u32; 0] = [];
        check_permutation(original, permuted, indexes);

        // shuffle
        let original: [Field; 8] = [1, 2, 3, 4, 5, 6, 7, 8];
        let permuted: [Field; 8] = [8, 1, 7, 2, 6, 3, 5, 4];
        let indexes: [u32; 8] = [7, 0, 6, 1, 5, 2, 4, 3];
        check_permutation(original, permuted, indexes);
    }

    #[test(should_fail_with = "Duplicated index")]
    fn test_duplicate_indexes() {
        let original: [Field; 3] = [1, 2, 3];
        let permuted: [Field; 3] = [1, 2, 1];
        let indexes: [u32; 3] = [0, 1, 0]; // duplicate index 0
        check_permutation(original, permuted, indexes);
    }

    #[test(should_fail_with = "Invalid index")]
    fn test_wrong_value_at_position() {
        let original: [Field; 3] = [1, 2, 3];
        let permuted: [Field; 3] = [1, 2, 99]; // wrong value at position 2
        let indexes: [u32; 3] = [0, 1, 2];
        check_permutation(original, permuted, indexes);
    }

    #[test(should_fail_with = "Invalid index")]
    fn test_swapped_values_wrong_indexes() {
        let original: [Field; 3] = [100, 200, 300];
        let permuted: [Field; 3] = [200, 100, 300];
        let indexes: [u32; 3] = [0, 1, 2]; // wrong index
        check_permutation(original, permuted, indexes);
    }

}
