use std::hash::Hasher;

// Note: `N` must be a power of 2.
#[derive(Eq)]
pub struct MerkleTree<let N: u32, H> {
    pub leaves: [Field; N],
    // nodes are the internal nodes of the Merkle tree, excluding the leaves
    pub nodes: [Field; N - 1],
}

impl<let N: u32, H> MerkleTree<N, H> {
    pub fn empty() -> Self
    where
        H: Hasher + Default,
    {
        let leaves = [0; N];
        let nodes = Self::compute_merkle_tree_nodes(leaves);
        MerkleTree { leaves, nodes }
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

    pub fn compute_merkle_tree_nodes(leaves: [Field; N]) -> [Field; N - 1]
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
