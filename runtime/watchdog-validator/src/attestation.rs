use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

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

// ── Measured boot + remote attestation (canon L0) ───────────────────────────────────────────
//
// A device's boot is a MEASURED chain: each stage records the content hash of what it ran
// (BootProofRecord.stageProofs, the vendored sourceos-spec contract). Attestation verifies that
// measured chain against a pinned golden policy — fail-closed. A device is trustworthy from
// power-on only if EVERY stage it ran was pinned and matched; an unpinned stage is an
// unmeasured surface and fails.
//
// Pure Rust, no arch-specific code: the same verifier runs in the initramfs of an aarch64 M2 and
// an x86_64 / riscv64 sovereign-silicon box — only the pinned policy differs per silicon. The
// rootfs stage's measured hash is bound to the dm-verity root, so "the base is immutable"
// (verity) and "the base that booted is the pinned one" (attestation) are ONE evidence chain.

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StageProof {
    pub stage_name: String,
    pub content_hash: String,
    pub verdict: String, // verified | skipped | failed | tampered
    #[serde(default)]
    pub artifact_ref: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BootProofRecord {
    pub outcome: String, // success | partial | failure | aborted
    #[serde(default)]
    pub device_ref: String,
    #[serde(default)]
    pub boot_plan_ref: String,
    #[serde(default)]
    pub stage_proofs: Vec<StageProof>,
    #[serde(default)]
    pub signature: Option<String>,
}

/// One pinned stage in the golden measured-boot chain.
#[derive(Debug, Clone)]
pub struct StagePin {
    pub stage_name: String,
    pub content_hash: String,
}

/// The golden measured-boot policy for one silicon/edition.
#[derive(Debug, Clone, Default)]
pub struct AttestationPolicy {
    pub expected_stages: Vec<StagePin>,
    pub rootfs_stage: Option<String>,       // defaults to "rootfs"
    pub rootfs_verity_root: Option<String>, // dm-verity root the rootfs stage must equal
    pub require_signature: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AttestOutcome {
    pub attested: bool,
    pub reasons: Vec<String>,
    pub verity_bound: bool,
}

fn is_sha256(s: &str) -> bool {
    s.len() == 7 + 64
        && s.starts_with("sha256:")
        && s[7..].bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Attest a measured boot against a pinned policy. Fail-closed.
pub fn attest_boot(record: &BootProofRecord, policy: &AttestationPolicy) -> AttestOutcome {
    let mut reasons: Vec<String> = Vec::new();

    // A policy that pins no stages could "attest" anything — refuse to be theater.
    if policy.expected_stages.is_empty() {
        return AttestOutcome {
            attested: false,
            reasons: vec!["attestation policy pins no stages — nothing measured".into()],
            verity_bound: false,
        };
    }

    // 1. the boot must have succeeded.
    if record.outcome != "success" {
        reasons.push(format!("boot outcome '{}' is not success", record.outcome));
    }
    if record.stage_proofs.is_empty() {
        reasons.push("no stageProofs — an unmeasured boot cannot be attested".into());
    }

    // 2. every stage that ran must have measured as 'verified'.
    for s in &record.stage_proofs {
        if s.verdict != "verified" {
            reasons.push(format!("stage '{}' verdict '{}' != verified", s.stage_name, s.verdict));
        }
    }

    // index measured stages by name
    let measured: std::collections::BTreeMap<&str, &StageProof> =
        record.stage_proofs.iter().map(|s| (s.stage_name.as_str(), s)).collect();
    let pinned: BTreeSet<&str> = policy.expected_stages.iter().map(|p| p.stage_name.as_str()).collect();

    // 3. every pinned stage present with an exact hash match.
    for pin in &policy.expected_stages {
        match measured.get(pin.stage_name.as_str()) {
            None => reasons.push(format!("expected stage '{}' missing from the boot proof", pin.stage_name)),
            Some(s) if s.content_hash != pin.content_hash => reasons.push(format!(
                "stage '{}' hash mismatch (measured {} != pinned {})",
                pin.stage_name, s.content_hash, pin.content_hash
            )),
            Some(_) => {}
        }
    }
    // 3b. fail-closed: no stage may run that isn't pinned (an unmeasured surface).
    for s in &record.stage_proofs {
        if !pinned.contains(s.stage_name.as_str()) {
            reasons.push(format!(
                "stage '{}' ran but is not pinned in the attestation policy (unmeasured surface)",
                s.stage_name
            ));
        }
    }

    // 4. dm-verity binding: the rootfs stage's measured hash == the pinned verity root.
    let verity_bound = policy.rootfs_verity_root.is_some();
    if let Some(root) = &policy.rootfs_verity_root {
        if !is_sha256(root) {
            reasons.push("rootfsVerityRoot must be sha256:<64hex>".into());
        }
        let stage = policy.rootfs_stage.as_deref().unwrap_or("rootfs");
        match measured.get(stage) {
            None => reasons.push(format!("rootfs stage '{stage}' absent — cannot bind the dm-verity root")),
            Some(s) if &s.content_hash != root => reasons.push(format!(
                "rootfs hash {} != pinned dm-verity root {} (booted base is not the verified base)",
                s.content_hash, root
            )),
            Some(_) => {}
        }
    }

    // 5. signed boot proof, if required.
    if policy.require_signature && record.signature.as_deref().unwrap_or("").is_empty() {
        reasons.push("attestation policy requires a signed boot proof".into());
    }

    AttestOutcome { attested: reasons.is_empty(), reasons, verity_bound }
}

#[cfg(test)]
mod attest_tests {
    use super::*;

    const VERITY: &str = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    fn stage(name: &str, hash: &str, verdict: &str) -> StageProof {
        StageProof { stage_name: name.into(), content_hash: hash.into(), verdict: verdict.into(), artifact_ref: String::new() }
    }
    fn good_stages() -> Vec<StageProof> {
        vec![
            stage("firmware", "sha256:1111111111111111111111111111111111111111111111111111111111111111", "verified"),
            stage("bootloader", "sha256:2222222222222222222222222222222222222222222222222222222222222222", "verified"),
            stage("kernel", "sha256:3333333333333333333333333333333333333333333333333333333333333333", "verified"),
            stage("rootfs", VERITY, "verified"),
        ]
    }
    fn policy() -> AttestationPolicy {
        AttestationPolicy {
            expected_stages: good_stages().iter().map(|s| StagePin { stage_name: s.stage_name.clone(), content_hash: s.content_hash.clone() }).collect(),
            rootfs_stage: Some("rootfs".into()),
            rootfs_verity_root: Some(VERITY.into()),
            require_signature: false,
        }
    }
    fn record(stages: Vec<StageProof>, outcome: &str) -> BootProofRecord {
        BootProofRecord { outcome: outcome.into(), device_ref: "urn:srcos:device:x".into(), boot_plan_ref: "p".into(), stage_proofs: stages, signature: None }
    }

    #[test]
    fn fully_measured_boot_attests() {
        let o = attest_boot(&record(good_stages(), "success"), &policy());
        assert!(o.attested && o.verity_bound, "{:?}", o.reasons);
    }
    #[test]
    fn non_success_outcome_rejected() {
        assert!(!attest_boot(&record(good_stages(), "partial"), &policy()).attested);
    }
    #[test]
    fn tampered_stage_rejected() {
        let mut s = good_stages();
        s[3] = stage("rootfs", VERITY, "tampered");
        assert!(!attest_boot(&record(s, "success"), &policy()).attested);
    }
    #[test]
    fn hash_mismatch_rejected() {
        let mut s = good_stages();
        s[2] = stage("kernel", "sha256:9999999999999999999999999999999999999999999999999999999999999999", "verified");
        let o = attest_boot(&record(s, "success"), &policy());
        assert!(!o.attested && o.reasons.iter().any(|r| r.contains("hash mismatch")));
    }
    #[test]
    fn unpinned_stage_rejected() {
        let mut s = good_stages();
        s.push(stage("mystery-blob", "sha256:7777777777777777777777777777777777777777777777777777777777777777", "verified"));
        let o = attest_boot(&record(s, "success"), &policy());
        assert!(!o.attested && o.reasons.iter().any(|r| r.contains("not pinned")));
    }
    #[test]
    fn dm_verity_mismatch_rejected() {
        let mut s = good_stages();
        s[3] = stage("rootfs", "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb", "verified");
        let mut pol = policy();
        // repin the rootfs expected hash so ONLY the verity binding fails
        pol.expected_stages = s.iter().map(|x| StagePin { stage_name: x.stage_name.clone(), content_hash: x.content_hash.clone() }).collect();
        let o = attest_boot(&record(s, "success"), &pol);
        assert!(!o.attested && o.reasons.iter().any(|r| r.contains("dm-verity")));
    }
    #[test]
    fn empty_policy_attests_nothing() {
        let pol = AttestationPolicy::default();
        assert!(!attest_boot(&record(good_stages(), "success"), &pol).attested);
    }
    #[test]
    fn require_signature_enforced() {
        let mut pol = policy();
        pol.require_signature = true;
        assert!(!attest_boot(&record(good_stages(), "success"), &pol).attested);
        let mut rec = record(good_stages(), "success");
        rec.signature = Some("MEUCIQD".to_string() + &"f".repeat(20));
        assert!(attest_boot(&rec, &pol).attested);
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
