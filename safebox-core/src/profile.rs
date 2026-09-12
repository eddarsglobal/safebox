#[derive(Debug, Clone)]
pub struct KdfProfile {
    pub memory_kib: u32,
    pub time_cost: u32,
    pub parallelism: u32,
}

impl Default for KdfProfile {
    fn default() -> Self {
        Self {
            memory_kib: 32 * 1024,
            time_cost: 3,
            parallelism: 1,
        }
    }
}
