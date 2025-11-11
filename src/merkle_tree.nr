use std::hash::Hasher;

// Note: `N` must be a power of 2.
#[derive(Eq)]
pub struct MerkleTree<let N: u32, H> {
    pub leaves: [Field; N],
    // nodes are the internal nodes of the Merkle tree, excluding the leaves
    pub nodes: [Field; N - 1],
}

impl<let N: u32, H> MerkleTree<N, H> {
    pub fn empty() -> Self {
        MerkleTree { leaves: [0; N], nodes: [0; N - 1] }
    }

    pub fn new(leaves: [Field; N]) -> Self
    where
        H: Hasher + Default,
    {
        let nodes = Self::compute_merkle_tree_nodes(leaves);
        MerkleTree { leaves, nodes }
    }

    pub fn get_root(self) -> Field {
        self.nodes[N - 2]
    }

    pub fn sibling_index(index: u32) -> u32 {
        assert(index < N, "Index out of bounds");
        if index % 2 == 0 {
            index + 1
        } else {
            index - 1
        }
    }

    // K is the length of the sibling path, which is the height of the Merkle tree
    pub fn get_sibling_path<let K: u32>(self, leaf_index: u32) -> [Field; K] {
        assert_eq(2.pow_32(K as Field), N as Field, "Invalid path length");

        let mut path = [0; K];
        let mut current_index = leaf_index;
        let mut subtree_width = N;

        let mut current_sibling_index = Self::sibling_index(current_index);

        path[0] = self.leaves[current_sibling_index];

        let mut subtree_offset: u32 = 0;

        for i in 1..K {
            current_index = current_index / 2;
            subtree_width = subtree_width / 2;

            current_sibling_index = Self::sibling_index(current_index);

            path[i] = self.nodes[subtree_offset + current_sibling_index];

            subtree_offset += subtree_width;
        }

        path
    }

    fn compute_merkle_tree_nodes(leaves: [Field; N]) -> [Field; N - 1]
    where
        H: Hasher + Default,
    {
        let mut nodes = [0; N - 1];

        let total_nodes = N - 1;
        let half_size = N / 2;

        // Hash base layer.
        for i in 0..half_size {
            nodes[i] = hash_nodes::<H>(leaves[2 * i], leaves[2 * i + 1]);
        }

        // Hash the other layers.
        for i in 0..(total_nodes - half_size) {
            nodes[half_size + i] = hash_nodes::<H>(nodes[2 * i], nodes[2 * i + 1]);
        }

        nodes
    }
}

pub fn hash_nodes<H>(left: Field, right: Field) -> Field
where
    H: Hasher + Default,
{
    let mut hasher: H = H::default();
    hasher.write(left);
    hasher.write(right);
    hasher.finish()
}

mod tests {
    use crate::merkle_tree::hash_nodes;
    use crate::{merkle_tree::MerkleTree, utils::poseidon2_hash};
    use poseidon::poseidon2::Poseidon2Hasher;

    #[test]
    fn test_hash_nodes(val1: Field, val2: Field) {
        let hash = hash_nodes::<Poseidon2Hasher>(val1, val2);
        assert_eq(hash, poseidon2_hash(val1, val2));
    }

    // test for smallest tree N = 2
    #[test]
    fn test_compute_nodes_size_2() {
        let tree = MerkleTree::<2, Poseidon2Hasher>::new([1, 2]);
        // for N=2, we have N-1 = 1 node
        assert_eq(tree.nodes.len(), 1);
        let expected_node = poseidon2_hash(1, 2);
        assert_eq(tree.nodes[0], expected_node);
    }

    // test for N=8
    #[test]
    fn test_compute_nodes_size_8() {
        let tree = MerkleTree::<8, Poseidon2Hasher>::new([1, 2, 3, 4, 5, 6, 7, 8]);
        assert_eq(tree.nodes.len(), 7);

        // base layer: nodes[0..4]
        let expected_hash_12 = poseidon2_hash(1, 2);
        let expected_hash_34 = poseidon2_hash(3, 4);
        let expected_hash_56 = poseidon2_hash(5, 6);
        let expected_hash_78 = poseidon2_hash(7, 8);
        assert_eq(tree.nodes[0], expected_hash_12);
        assert_eq(tree.nodes[1], expected_hash_34);
        assert_eq(tree.nodes[2], expected_hash_56);
        assert_eq(tree.nodes[3], expected_hash_78);

        // upper layer: nodes[4..7]
        // nodes[4] = hash(nodes[0], nodes[1]) = hash(hash(1,2), hash(3,4))
        let expected_hash_left = poseidon2_hash(expected_hash_12, expected_hash_34);
        assert_eq(tree.nodes[4], expected_hash_left);

        // nodes[5] = hash(nodes[2], nodes[3]) = hash(hash(5,6), hash(7,8))
        let expected_hash_right = poseidon2_hash(expected_hash_56, expected_hash_78);
        assert_eq(tree.nodes[5], expected_hash_right);

        // nodes[6] = hash(nodes[4], nodes[5]) = root
        let expected_root = poseidon2_hash(expected_hash_left, expected_hash_right);
        assert_eq(tree.nodes[6], expected_root);
    }

    // test empty tree
    #[test]
    fn test_compute_nodes_empty_tree() {
        let tree = MerkleTree::<4, Poseidon2Hasher>::empty();
        // Empty tree should have all nodes = 0
        assert_eq(tree.nodes.len(), 3);
        assert_eq(tree.nodes[0], 0);
        assert_eq(tree.nodes[1], 0);
        assert_eq(tree.nodes[2], 0);
    }

    // test for N=8
    #[test]
    fn test_get_root_size_8() {
        let tree = MerkleTree::<8, Poseidon2Hasher>::new([1, 2, 3, 4, 5, 6, 7, 8]);
        let root = tree.get_root();
        // For N=8, root is nodes[6] = hash(hash(hash(1,2), hash(3,4)), hash(hash(5,6), hash(7,8)))
        let expected_hash_12 = poseidon2_hash(1, 2);
        let expected_hash_34 = poseidon2_hash(3, 4);
        let expected_hash_56 = poseidon2_hash(5, 6);
        let expected_hash_78 = poseidon2_hash(7, 8);
        let expected_hash_left = poseidon2_hash(expected_hash_12, expected_hash_34);
        let expected_hash_right = poseidon2_hash(expected_hash_56, expected_hash_78);
        let expected_root = poseidon2_hash(expected_hash_left, expected_hash_right);
        assert_eq(root, expected_root);
    }

    // test that root is at the correct index (N - 2)
    #[test]
    fn test_get_root_correct_index() {
        let tree2 = MerkleTree::<2, Poseidon2Hasher>::new([10, 20]);
        assert_eq(tree2.get_root(), tree2.nodes[0]);

        let tree4 = MerkleTree::<4, Poseidon2Hasher>::new([10, 20, 30, 40]);
        assert_eq(tree4.get_root(), tree4.nodes[2]);

        let tree8 = MerkleTree::<8, Poseidon2Hasher>::new([1, 2, 3, 4, 5, 6, 7, 8]);
        assert_eq(tree8.get_root(), tree8.nodes[6]);

        let leaves16 = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];
        let tree16 = MerkleTree::<16, Poseidon2Hasher>::new(leaves16);
        assert_eq(tree16.get_root(), tree16.nodes[14]);
    }

    // test empty tree
    #[test]
    fn test_get_root_empty_tree() {
        let tree = MerkleTree::<4, Poseidon2Hasher>::empty();
        let root = tree.get_root();
        assert_eq(root, 0);
    }

    // test for N=8
    #[test]
    fn test_sibling_index_size_8_all_indices() {
        for i in 0..4 {
            let even_sibling_index = 2 * i;
            let odd_sibling_index = 2 * i + 1;
            assert_eq(
                MerkleTree::<8, Poseidon2Hasher>::sibling_index(even_sibling_index),
                odd_sibling_index,
            ); // even -> +1
            assert_eq(
                MerkleTree::<8, Poseidon2Hasher>::sibling_index(odd_sibling_index),
                even_sibling_index,
            ); // odd -> -1
        }
    }

    #[test]
    fn test_sibling_index_symmetry_size_16() {
        for i in 0..16 {
            let sibling = MerkleTree::<16, Poseidon2Hasher>::sibling_index(i);
            let sibling_of_sibling = MerkleTree::<16, Poseidon2Hasher>::sibling_index(sibling);
            assert_eq(sibling_of_sibling, i, "sibling of sibling should be the same as the index");
        }
    }

    // boundary conditions: index == N (should fail)
    #[test(should_fail_with = "Index out of bounds")]
    fn test_sibling_index_out_of_bounds_size_16() {
        let _ = MerkleTree::<16, Poseidon2Hasher>::sibling_index(16);
    }

    // test for smallest tree N = 2
    #[test]
    fn test_get_sibling_path_size_2_leaf() {
        let tree = MerkleTree::<2, Poseidon2Hasher>::new([1, 2]);
        let sibling_path = tree.get_sibling_path::<1>(0);
        // For leaf 0, sibling is leaf 1
        assert_eq(sibling_path[0], 2);
        let sibling_path2 = tree.get_sibling_path::<1>(1);
        // For leaf 1, sibling is leaf 0
        assert_eq(sibling_path2[0], 1);
    }

    // test for N=4
    #[test]
    fn test_get_sibling_path_size_4_leaf() {
        let tree = MerkleTree::<4, Poseidon2Hasher>::new([1, 2, 3, 4]);
        let expected_hash_12 = poseidon2_hash(1, 2);
        let expected_hash_34 = poseidon2_hash(3, 4);
        let sibling_path = tree.get_sibling_path::<2>(0);
        assert_eq(sibling_path[0], 2);
        assert_eq(sibling_path[1], expected_hash_34);
        let sibling_path2 = tree.get_sibling_path::<2>(1);
        assert_eq(sibling_path2[0], 1);
        assert_eq(sibling_path2[1], expected_hash_34);
        let sibling_path3 = tree.get_sibling_path::<2>(2);
        assert_eq(sibling_path3[0], 4);
        assert_eq(sibling_path3[1], expected_hash_12);
        let sibling_path4 = tree.get_sibling_path::<2>(3);
        assert_eq(sibling_path4[0], 3);
        assert_eq(sibling_path4[1], expected_hash_12);
    }

    #[test]
    fn test_get_sibling_path_can_reconstruct_root() {
        let leaves = [100, 200, 300, 400];
        let tree = MerkleTree::<4, Poseidon2Hasher>::new(leaves);
        let root = tree.get_root();

        // for each leaf, get its sibling path and verify it can reconstruct the root
        for i in 0..4 {
            let sibling_path = tree.get_sibling_path::<2>(i);
            let leaf = leaves[i];

            let (level0_hash_left, level0_hash_right) = if i % 2 == 0 {
                (leaf, sibling_path[0])
            } else {
                (sibling_path[0], leaf)
            };

            let level0_hash = poseidon2_hash(level0_hash_left, level0_hash_right);

            let (level1_hash_left, level1_hash_right) = if (i / 2) % 2 == 0 {
                (level0_hash, sibling_path[1])
            } else {
                (sibling_path[1], level0_hash)
            };
            let level1_hash = poseidon2_hash(level1_hash_left, level1_hash_right);

            assert_eq(level1_hash, root, "Sibling path should reconstruct root");
        }
    }

    #[export]
    fn test(leaves: [Field; 4]) -> Field {
        let mut level0_hash = 0;
        for i in 0..4 {
            level0_hash = if i % 2 == 0 {
                leaves[i] * 10
            } else {
                leaves[i + 1] * 11
            };
        }
        level0_hash
    }

}
