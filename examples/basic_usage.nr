// Basic usage examples for the Merkle tree library

use merkle::{
    MerkleTree, UnbalancedMerkleTree, check_membership, assert_check_membership,
    create_tree_with_root, create_sha_tree_with_root, create_membership_witness,
    verify_membership, create_and_verify_membership, reconstruct_root,
    MembershipWitness, sibling_index, root_from_sibling_path
};

fn main() {
    // Example 1: Basic Merkle Tree
    let leaves = [1, 2, 3, 4];
    let tree = MerkleTree::new(leaves);
    let root = tree.get_root();
    
    // Generate membership proof
    let sibling_path = tree.get_sibling_path::<2>(1);
    let is_member = check_membership(2, 1, sibling_path, root);
    assert(is_member, "Leaf should be in tree");
    
    // Example 2: Using convenience functions
    let (tree2, root2) = create_tree_with_root([10, 20, 30, 40]);
    let witness = create_membership_witness::<4, 2>(tree2, 0);
    let verified = verify_membership(10, witness, root2);
    assert(verified, "Membership should be verified");
    
    // Example 3: SHA256 Merkle Tree
    let sha_tree = MerkleTree::new_sha([100, 200, 300, 400]);
    let sha_root = sha_tree.get_root();
    
    // Example 4: Unbalanced Merkle Tree
    let unbalanced_leaves = [1, 2, 3, 4, 5, 6, 7]; // 7 leaves (not power of 2)
    let unbalanced_tree = UnbalancedMerkleTree::new_sha::<8, 3>(unbalanced_leaves, 7);
    let unbalanced_root = unbalanced_tree.get_root();
    
    // Example 5: Complete workflow
    let test_leaves = [5, 10, 15, 20];
    let is_verified = create_and_verify_membership::<4, 2>(test_leaves, 2);
    assert(is_verified, "Complete workflow should work");
    
    // Example 6: Manual root reconstruction
    let leaf = 15;
    let leaf_index = 2;
    let path = [20, 10]; // sibling path
    let reconstructed_root = reconstruct_root(leaf, leaf_index, path);
    
    // Example 7: Utility functions
    let sibling_idx = sibling_index(1); // Should be 0
    assert(sibling_idx == 0, "Sibling index should be 0");
}
