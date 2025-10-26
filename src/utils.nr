use crate::membership::{check_membership, MembershipWitness};
use crate::merkle_tree::MerkleTree;

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

/// Computes sha256 hash of 2 input fields.
///
/// @returns A truncated field (i.e., the first byte is always 0).
pub fn accumulate_sha256(v0: Field, v1: Field) -> Field {
    // Concatenate two fields into 32 x 2 = 64 bytes
    let v0_as_bytes: [u8; 32] = v0.to_be_bytes();
    let v1_as_bytes: [u8; 32] = v1.to_be_bytes();
    let hash_input_flattened = v0_as_bytes.concat(v1_as_bytes);

    sha256_to_field(hash_input_flattened)
}

pub fn sha256_to_field<let N: u32>(bytes_to_hash: [u8; N]) -> Field {
    let sha256_hashed = sha256::digest(bytes_to_hash);
    let hash_in_a_field = field_from_bytes_32_trunc(sha256_hashed);

    hash_in_a_field
}

// Convert a 32 byte array to a field element by truncating the final byte
pub fn field_from_bytes_32_trunc(bytes32: [u8; 32]) -> Field {
    // Convert it to a field element
    let mut v = 1;
    let mut high = 0 as Field;
    let mut low = 0 as Field;

    for i in 0..15 {
        // covers bytes 16..30 (31 is truncated and ignored)
        low = low + (bytes32[15 + 15 - i] as Field) * v;
        v = v * 256;
        // covers bytes 0..14
        high = high + (bytes32[14 - i] as Field) * v;
    }
    // covers byte 15
    low = low + (bytes32[15] as Field) * v;

    low + high * v
}

/// Create a Merkle tree and return both the tree and its root
pub fn create_tree_with_root<let N: u32>(
    leaves: [Field; N],
    hasher: fn(Field, Field) -> Field,
) -> (MerkleTree<N>, Field) {
    let tree = MerkleTree::new(leaves, hasher);
    let root = tree.get_root();
    (tree, root)
}

/// Create a Poseidon Merkle tree and return both the tree and its root
pub fn create_poseidon_tree_with_root<let N: u32>(leaves: [Field; N]) -> (MerkleTree<N>, Field) {
    let tree = MerkleTree::new_poseidon(leaves);
    let root = tree.get_root();
    (tree, root)
}

/// Create a SHA256 Merkle tree and return both the tree and its root
pub fn create_sha256_tree_with_root<let N: u32>(leaves: [Field; N]) -> (MerkleTree<N>, Field) {
    let tree = MerkleTree::new_sha256(leaves);
    let root = tree.get_root();
    (tree, root)
}

/// Generate a complete membership witness for a leaf
pub fn create_membership_witness<let N: u32, let K: u32>(
    tree: MerkleTree<N>,
    leaf_index: u32,
) -> MembershipWitness<K> {
    let sibling_path = tree.get_sibling_path::<K>(leaf_index);
    MembershipWitness { leaf_index: leaf_index as Field, sibling_path }
}

/// Verify a leaf exists in a tree using a membership witness
pub fn verify_membership<let K: u32>(
    leaf: Field,
    witness: MembershipWitness<K>,
    root: Field,
    hasher: fn(Field, Field) -> Field,
) -> bool {
    check_membership(leaf, witness.leaf_index, witness.sibling_path, root, hasher)
}

/// Create a tree, generate a membership proof, and verify it
pub fn create_and_verify_membership<let N: u32, let K: u32>(
    leaves: [Field; N],
    leaf_index: u32,
    hasher: fn(Field, Field) -> Field,
) -> bool {
    let (tree, root) = create_tree_with_root(leaves, hasher);
    let witness = create_membership_witness::<N, K>(tree, leaf_index);
    let leaf_value = leaves[leaf_index];
    verify_membership(leaf_value, witness, root, hasher)
}
