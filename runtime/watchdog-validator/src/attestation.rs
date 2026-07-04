use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AttestationSnapshot {
    pub aum_id: String,
    pub kernel_hash: String,
    pub policy_digest: String,
}

pub fn snapshot() -> AttestationSnapshot {
    AttestationSnapshot {
        aum_id: "agent.watchdog.validator".to_string(),
        kernel_hash: "sha256:deadbeef".to_string(),
        policy_digest: "sha256:cafebabe".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn snapshot_contains_expected_fields() {
        let snap = snapshot();
        assert!(snap.aum_id.starts_with("agent."));
        assert!(snap.kernel_hash.starts_with("sha256:"));
        assert!(snap.policy_digest.starts_with("sha256:"));
    }
}
