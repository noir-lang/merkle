use crate::membership::{check_membership, MembershipWitness};
use crate::merkle_tree::MerkleTree;
use std::hash::Hasher;

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
