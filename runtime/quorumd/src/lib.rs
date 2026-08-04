use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Vote {
    pub signer: String,
    pub verdict: String,
}

// ── Canonical validator-quorum verifier (the on-device + CLI verifier) ──────────────────────
//
// Conforms to the authoritative QuorumProof shape (mcp-a2a-zero-trust ::
// schemas/canonical/quorum_proof.schema.json). This is the SAME contract the prophet-platform
// Python verifier (PP #1370) checks; the two are twins over one shape, not two schemas.
//
// Pure Rust, no arch-specific code — the identical binary logic runs on aarch64 (Apple Silicon),
// x86_64, and riscv64. This is why it lives at L0 in Rust and not in the cloud runtime: the
// canon runs this check IN the boot path (bootProbe halts on a failed Genesis quorum), before
// any network exists — a device decides its own trust locally, on whatever silicon it is.

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct QuorumSignature {
    pub kind: String,
    pub spiffe_id: String,
    pub sig: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct QuorumProof {
    pub rule: String,
    pub validators: Vec<String>,
    pub signed_payload_hash: String,
    pub signatures: Vec<QuorumSignature>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct QuorumOutcome {
    pub ok: bool,
    pub reasons: Vec<String>,
}

/// Parse a `MofN-kind` rule (e.g. "2of3-human"). Returns None on M<1, N<1, or M>N.
fn parse_rule(rule: &str) -> Option<(usize, usize, &str)> {
    let (m_n, kind) = rule.split_once('-')?;
    let (m, n) = m_n.split_once("of")?;
    let threshold: usize = m.parse().ok()?;
    let total: usize = n.parse().ok()?;
    if threshold < 1 || total < 1 || threshold > total {
        return None;
    }
    Some((threshold, total, kind))
}

fn is_payload_hash(s: &str) -> bool {
    s.len() == 7 + 64
        && s.starts_with("sha256:")
        && s[7..].bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
}

/// Verify a QuorumProof: shape + M-of-N threshold, fail-closed. When `payload_hash` is given the
/// proof must be over exactly that payload (binds the quorum to the thing being admitted).
///
/// NOTE (v1): this checks that `threshold` DISTINCT listed validators each supplied a non-trivial
/// signature. Cryptographic verification of each `sig` against the validator's FIDO2/NitroKey
/// public key is the next step; the shape and threshold arithmetic are canonical here.
pub fn verify_quorum(proof: &QuorumProof, payload_hash: Option<&str>) -> QuorumOutcome {
    let mut reasons: Vec<String> = Vec::new();

    let (threshold, total, kind) = match parse_rule(&proof.rule) {
        Some(r) => r,
        None => {
            return QuorumOutcome {
                ok: false,
                reasons: vec![format!("rule '{}' does not parse as MofN-kind (1<=M<=N)", proof.rule)],
            }
        }
    };

    let vset: BTreeSet<&str> = proof.validators.iter().map(String::as_str).collect();
    if vset.len() != proof.validators.len() {
        reasons.push("validators list has duplicates".into());
    }
    if vset.len() < total {
        reasons.push(format!("rule needs {} validators; only {} listed", total, vset.len()));
    }

    if !is_payload_hash(&proof.signed_payload_hash) {
        reasons.push("signed_payload_hash must be sha256:<64hex>".into());
    } else if let Some(ph) = payload_hash {
        if proof.signed_payload_hash != ph {
            reasons.push("signed_payload_hash does not match the admitted payload (quorum unbound)".into());
        }
    }

    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut valid = 0usize;
    for (i, s) in proof.signatures.iter().enumerate() {
        if s.kind != kind {
            reasons.push(format!("signature[{i}] kind '{}' != rule kind '{kind}'", s.kind));
            continue;
        }
        if !vset.contains(s.spiffe_id.as_str()) {
            reasons.push(format!("signature[{i}] signer '{}' is not a listed validator", s.spiffe_id));
            continue;
        }
        if seen.contains(s.spiffe_id.as_str()) {
            reasons.push(format!("signature[{i}] duplicate signer '{}'", s.spiffe_id));
            continue;
        }
        if s.sig.len() < 16 {
            reasons.push(format!("signature[{i}] sig too short / missing"));
            continue;
        }
        seen.insert(s.spiffe_id.as_str());
        valid += 1;
    }
    if valid < threshold {
        reasons.push(format!(
            "{valid} valid distinct signature(s) < threshold {threshold} (rule {})",
            proof.rule
        ));
    }

    QuorumOutcome { ok: reasons.is_empty(), reasons }
}

// ── Cryptographic quorum: real validator signatures (Ed25519 / NitroKey / sovereign key) ────
//
// `verify_quorum` checks the SHAPE + threshold + that distinct listed validators supplied a
// signature. `verify_quorum_signed` goes the last mile: each signature must be a valid Ed25519
// signature by the validator's REGISTERED public key over the signed_payload_hash. An attacker
// cannot forge a validator's vote without that validator's private key — "every validator keeps
// its own truth" made real. Ed25519 is the NitroKey / OpenSSH / sovereign-key form; pure Rust,
// no arch-specific code, so it verifies the same on aarch64 / x86_64 / riscv64. Keys are pinned
// OUT OF BAND (Genesis enrollment) — a signature counts only if the signer is in BOTH the proof's
// `validators` and the registered key set. (ES256/WebAuthn assertions are a follow-up.)

use ed25519_dalek::{Signature, Verifier, VerifyingKey};

/// spiffe_id -> Ed25519 public key, hex-encoded (64 hex chars = 32 bytes).
pub type ValidatorKeys = std::collections::BTreeMap<String, String>;

fn ed25519_ok(pubkey_hex: &str, message: &[u8], sig_hex: &str) -> bool {
    let pk = match hex::decode(pubkey_hex) {
        Ok(b) => b,
        Err(_) => return false,
    };
    let pk: [u8; 32] = match pk.try_into() {
        Ok(a) => a,
        Err(_) => return false,
    };
    let sig_bytes = match hex::decode(sig_hex) {
        Ok(b) => b,
        Err(_) => return false,
    };
    let vk = match VerifyingKey::from_bytes(&pk) {
        Ok(v) => v,
        Err(_) => return false,
    };
    let sig = match Signature::from_slice(&sig_bytes) {
        Ok(s) => s,
        Err(_) => return false,
    };
    vk.verify(message, &sig).is_ok()
}

/// Cryptographic quorum verification: structural validity AND >= threshold DISTINCT signatures
/// that each cryptographically verify (Ed25519) against the signer's registered key over the
/// signed_payload_hash. Fail-closed: an unregistered signer or an invalid signature does not count.
pub fn verify_quorum_signed(
    proof: &QuorumProof,
    payload_hash: Option<&str>,
    keys: &ValidatorKeys,
) -> QuorumOutcome {
    // Start from the structural check (shape, rule, payload binding, distinct listed signers).
    let mut reasons = verify_quorum(proof, payload_hash).reasons;

    let (threshold, _total, kind) = match parse_rule(&proof.rule) {
        Some(r) => r,
        None => return QuorumOutcome { ok: false, reasons },
    };
    let vset: BTreeSet<&str> = proof.validators.iter().map(String::as_str).collect();
    let message = proof.signed_payload_hash.as_bytes();

    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut crypto_valid = 0usize;
    for (i, s) in proof.signatures.iter().enumerate() {
        if s.kind != kind || !vset.contains(s.spiffe_id.as_str()) || seen.contains(s.spiffe_id.as_str()) {
            continue; // any structural reason is already recorded above
        }
        match keys.get(&s.spiffe_id) {
            None => reasons.push(format!("signature[{i}] signer '{}' has no registered key", s.spiffe_id)),
            Some(pubkey) => {
                if ed25519_ok(pubkey, message, &s.sig) {
                    seen.insert(s.spiffe_id.as_str());
                    crypto_valid += 1;
                } else {
                    reasons.push(format!("signature[{i}] Ed25519 signature invalid for '{}'", s.spiffe_id));
                }
            }
        }
    }
    if crypto_valid < threshold {
        reasons.push(format!("{crypto_valid} cryptographically-valid signature(s) < threshold {threshold}"));
    }

    QuorumOutcome { ok: reasons.is_empty(), reasons }
}

// ── Device enrollment gate — the fusion (attested boot × cryptographic quorum) ──────────────
//
// A device joins the fleet only if BOTH hold: its boot ATTESTS (the measured chain matches the
// pinned golden policy, watchdog_validator::attest_boot) AND a validator quorum CRYPTOGRAPHICALLY
// co-signs THIS enrollment (verify_quorum_signed, bound to a payload hash over the device + its
// attested boot). Neither alone is enough: an attested boot with no quorum is a device nobody
// vouched for; a quorum with no attestation vouches for an unmeasured box. This is the canon's
// Genesis binding, complete — and it runs on-device, on any silicon, in pure Rust.

use sha2::{Digest, Sha256};
use watchdog_validator::attestation::{attest_boot, AttestationPolicy, BootProofRecord};

/// The payload the validators must co-sign: binds the device to the EXACT boot that was measured,
/// so a quorum vote is valid for this device + this boot only (not replayable elsewhere).
pub fn enrollment_payload_hash(device_ref: &str, boot: &BootProofRecord) -> String {
    let mut h = Sha256::new();
    h.update(device_ref.as_bytes());
    h.update(b"|outcome=");
    h.update(boot.outcome.as_bytes());
    // ordered (stage, hash) pairs — the measured chain identity.
    let mut stages: Vec<(&str, &str)> = boot
        .stage_proofs
        .iter()
        .map(|s| (s.stage_name.as_str(), s.content_hash.as_str()))
        .collect();
    stages.sort();
    for (name, hash) in stages {
        h.update(b"|");
        h.update(name.as_bytes());
        h.update(b"=");
        h.update(hash.as_bytes());
    }
    format!("sha256:{}", hex::encode(h.finalize()))
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct EnrollOutcome {
    pub enrolled: bool,
    pub reasons: Vec<String>,
    pub payload_hash: String,
}

/// Enroll a device iff its boot attests AND a cryptographic validator quorum co-signs the
/// enrollment payload. Fail-closed: either check failing blocks enrollment.
pub fn enroll_device(
    device_ref: &str,
    boot: &BootProofRecord,
    policy: &AttestationPolicy,
    quorum: &QuorumProof,
    keys: &ValidatorKeys,
) -> EnrollOutcome {
    let mut reasons: Vec<String> = Vec::new();

    let att = attest_boot(boot, policy);
    if !att.attested {
        for r in &att.reasons {
            reasons.push(format!("attestation: {r}"));
        }
    }

    let payload_hash = enrollment_payload_hash(device_ref, boot);
    let q = verify_quorum_signed(quorum, Some(&payload_hash), keys);
    if !q.ok {
        for r in &q.reasons {
            reasons.push(format!("quorum: {r}"));
        }
    }

    EnrollOutcome { enrolled: reasons.is_empty(), reasons, payload_hash }
}

// ── Macro-quorum over the k3s master triad: Lazerus-style BLS quorum_sigs ────────────────────
//
// The "k3 regime" is the real k8s control plane — three k3s HA masters, each head of one cluster.
// Each master publishes a Lazerus Integrity Receipt carrying an aggregatable BLS quorum
// (`quorum_sigs`) over the state_root it commits to. This is the on-device SHAPE + threshold
// verifier for that macro-quorum — the BLS twin of `verify_quorum` (which is the Ed25519 side).
// It checks: the rule parses, enough distinct masters are listed, each `quorum_sig` is a
// well-formed `bls:` token by a listed master, the threshold is met, and (when a state_root is
// given to bind against) the quorum signs exactly that state — so a macro-quorum vote is bound to
// the state being failed-back-to, never replayable onto another.
//
// The cryptographic pairing check — e(sig, G2) == e(H(state_root), aggregated_pk) — is the next
// step and is DELIBERATELY DEFERRED: it is blocked on pinning the Lazerus BLS ciphersuite (curve
// side G1/G2 + the hash-to-curve DST). Implementing a "real" verifier before that suite is fixed
// would be an unfalsifiable guess that cannot be shown to interoperate — worse than an honest
// shape gate. This is the exact layering already in this file: `verify_quorum` (shape/threshold)
// shipped before `verify_quorum_signed` (Ed25519 crypto). Pure Rust, no new deps → the identical
// logic runs on aarch64 / x86_64 / riscv64, the way an on-device control-plane check must.

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BlsSignature {
    pub master: String, // the signing k3s master identity (DID)
    pub sig: String,    // "bls:<96 or 192 hex>" — a BLS12-381 G1/G2 signature token
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct BlsQuorumProof {
    pub rule: String,               // "MofN-kind", e.g. "2of3-master"
    pub masters: Vec<String>,       // the k3s master identities eligible to sign
    pub state_root: String,         // "sha256:<64hex>" — the state the quorum commits to
    pub signatures: Vec<BlsSignature>,
}

/// A `bls:` signature token: `bls:` + 96 hex (G1, 48 bytes) or 192 hex (G2, 96 bytes). Matches the
/// consumer-side grammar (sociosphere automation/lazerus.py RE_BLS_SIG) so the two ends agree.
fn is_bls_sig(s: &str) -> bool {
    if let Some(hexpart) = s.strip_prefix("bls:") {
        (hexpart.len() == 96 || hexpart.len() == 192)
            && hexpart.bytes().all(|b| b.is_ascii_digit() || (b'a'..=b'f').contains(&b))
    } else {
        false
    }
}

/// Verify a BLS macro-quorum proof: shape + M-of-N threshold + optional state binding, fail-closed.
/// When `bind_state_root` is `Some`, the proof must commit to exactly that state (binds the
/// macro-quorum to the state being failed back to). Cryptographic aggregate verification is the
/// deferred next step (see the section note) — this establishes the verifiable shape it will sit on.
pub fn verify_bls_quorum(proof: &BlsQuorumProof, bind_state_root: Option<&str>) -> QuorumOutcome {
    let mut reasons: Vec<String> = Vec::new();

    let (threshold, total, _kind) = match parse_rule(&proof.rule) {
        Some(r) => r,
        None => {
            return QuorumOutcome {
                ok: false,
                reasons: vec![format!("rule '{}' does not parse as MofN-kind (1<=M<=N)", proof.rule)],
            }
        }
    };

    let mset: BTreeSet<&str> = proof.masters.iter().map(String::as_str).collect();
    if mset.len() != proof.masters.len() {
        reasons.push("masters list has duplicates".into());
    }
    if mset.len() < total {
        reasons.push(format!("rule needs {} masters; only {} listed", total, mset.len()));
    }

    if !is_payload_hash(&proof.state_root) {
        reasons.push("state_root must be sha256:<64hex>".into());
    } else if let Some(want) = bind_state_root {
        if proof.state_root != want {
            reasons.push("state_root does not match the state being admitted (quorum unbound)".into());
        }
    }

    let mut seen: BTreeSet<&str> = BTreeSet::new();
    let mut valid = 0usize;
    for (i, s) in proof.signatures.iter().enumerate() {
        if !mset.contains(s.master.as_str()) {
            reasons.push(format!("signature[{i}] master '{}' is not a listed master", s.master));
            continue;
        }
        if seen.contains(s.master.as_str()) {
            reasons.push(format!("signature[{i}] duplicate master '{}'", s.master));
            continue;
        }
        if !is_bls_sig(&s.sig) {
            reasons.push(format!("signature[{i}] '{}' is not a bls: token", s.sig));
            continue;
        }
        seen.insert(s.master.as_str());
        valid += 1;
    }
    if valid < threshold {
        reasons.push(format!(
            "{valid} valid distinct BLS signature(s) < threshold {threshold} (rule {})",
            proof.rule
        ));
    }

    QuorumOutcome { ok: reasons.is_empty(), reasons }
}

pub fn aggregate(votes: &[Vote]) -> Option<String> {
    let mut counts = std::collections::BTreeMap::<String, usize>::new();
    for vote in votes {
        *counts.entry(vote.verdict.clone()).or_default() += 1;
    }
    counts
        .into_iter()
        .max_by_key(|(_, count)| *count)
        .map(|(verdict, _)| verdict)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn picks_majority_verdict() {
        let votes = vec![
            Vote { signer: "validator@v1".into(), verdict: "reseal_resume".into() },
            Vote { signer: "validator@v2".into(), verdict: "reseal_resume".into() },
            Vote { signer: "watchdog@w1".into(), verdict: "terminate".into() },
        ];
        assert_eq!(aggregate(&votes).as_deref(), Some("reseal_resume"));
    }

    const PH: &str = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    fn validators() -> Vec<String> {
        vec!["spiffe://v/1".into(), "spiffe://v/2".into(), "spiffe://v/3".into()]
    }
    fn sig(v: &str) -> QuorumSignature {
        QuorumSignature { kind: "human".into(), spiffe_id: v.into(), sig: "MEUCIQD".to_string() + &"f".repeat(20) }
    }
    fn proof(sigs: Vec<QuorumSignature>) -> QuorumProof {
        QuorumProof { rule: "2of3-human".into(), validators: validators(), signed_payload_hash: PH.into(), signatures: sigs }
    }

    #[test]
    fn valid_two_of_three_passes() {
        let p = proof(vec![sig("spiffe://v/1"), sig("spiffe://v/2")]);
        assert!(verify_quorum(&p, Some(PH)).ok);
    }

    #[test]
    fn below_threshold_fails() {
        assert!(!verify_quorum(&proof(vec![sig("spiffe://v/1")]), None).ok);
    }

    #[test]
    fn non_validator_signer_fails() {
        let p = proof(vec![sig("spiffe://v/1"), sig("spiffe://intruder")]);
        let o = verify_quorum(&p, None);
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("not a listed validator")));
    }

    #[test]
    fn duplicate_signer_not_counted_twice() {
        let p = proof(vec![sig("spiffe://v/1"), sig("spiffe://v/1")]);
        let o = verify_quorum(&p, None);
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("duplicate")));
    }

    #[test]
    fn payload_hash_binding_enforced() {
        let other = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
        let o = verify_quorum(&proof(vec![sig("spiffe://v/1"), sig("spiffe://v/2")]), Some(other));
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("does not match")));
    }

    #[test]
    fn malformed_rule_fails() {
        let mut p = proof(vec![sig("spiffe://v/1"), sig("spiffe://v/2")]);
        p.rule = "4of3-human".into();
        assert!(!verify_quorum(&p, None).ok);
    }

    #[test]
    fn kind_mismatch_fails() {
        let p = proof(vec![
            QuorumSignature { kind: "machine".into(), spiffe_id: "spiffe://v/1".into(), sig: "x".repeat(20) },
            QuorumSignature { kind: "machine".into(), spiffe_id: "spiffe://v/2".into(), sig: "x".repeat(20) },
        ]);
        assert!(!verify_quorum(&p, None).ok);
    }

    // ── cryptographic quorum (Ed25519) ─────────────────────────────────────────────────────
    use ed25519_dalek::{Signer, SigningKey};

    // deterministic key per validator (seed = validator index), so tests need no RNG.
    fn keypair(seed: u8) -> (SigningKey, String) {
        let sk = SigningKey::from_bytes(&[seed; 32]);
        (sk.clone(), hex::encode(sk.verifying_key().to_bytes()))
    }
    fn real_sig(sk: &SigningKey, spiffe: &str, payload_hash: &str) -> QuorumSignature {
        let sig = sk.sign(payload_hash.as_bytes());
        QuorumSignature { kind: "human".into(), spiffe_id: spiffe.into(), sig: hex::encode(sig.to_bytes()) }
    }

    #[test]
    fn valid_ed25519_quorum_passes() {
        let (sk1, pk1) = keypair(1);
        let (sk2, pk2) = keypair(2);
        let (_sk3, pk3) = keypair(3);
        let mut keys = ValidatorKeys::new();
        keys.insert("spiffe://v/1".into(), pk1);
        keys.insert("spiffe://v/2".into(), pk2);
        keys.insert("spiffe://v/3".into(), pk3);
        let p = proof(vec![real_sig(&sk1, "spiffe://v/1", PH), real_sig(&sk2, "spiffe://v/2", PH)]);
        let o = verify_quorum_signed(&p, Some(PH), &keys);
        assert!(o.ok, "{:?}", o.reasons);
    }

    #[test]
    fn forged_signature_fails() {
        let (sk1, pk1) = keypair(1);
        let (_sk2, pk2) = keypair(2);
        let mut keys = ValidatorKeys::new();
        keys.insert("spiffe://v/1".into(), pk1);
        keys.insert("spiffe://v/2".into(), pk2);
        keys.insert("spiffe://v/3".into(), keypair(3).1);
        // v2's signature is garbage (not signed by v2's key) — must not count.
        let forged = QuorumSignature { kind: "human".into(), spiffe_id: "spiffe://v/2".into(), sig: "ab".repeat(32) };
        let p = proof(vec![real_sig(&sk1, "spiffe://v/1", PH), forged]);
        let o = verify_quorum_signed(&p, Some(PH), &keys);
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("Ed25519 signature invalid")));
    }

    #[test]
    fn signature_over_wrong_payload_fails() {
        // v2 signs a DIFFERENT payload — valid signature, wrong message → does not verify.
        let (sk1, pk1) = keypair(1);
        let (sk2, pk2) = keypair(2);
        let mut keys = ValidatorKeys::new();
        keys.insert("spiffe://v/1".into(), pk1);
        keys.insert("spiffe://v/2".into(), pk2);
        keys.insert("spiffe://v/3".into(), keypair(3).1);
        let other = "sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc";
        let p = proof(vec![real_sig(&sk1, "spiffe://v/1", PH), real_sig(&sk2, "spiffe://v/2", other)]);
        let o = verify_quorum_signed(&p, Some(PH), &keys);
        assert!(!o.ok);
    }

    #[test]
    fn unregistered_signer_fails() {
        let (sk1, pk1) = keypair(1);
        let (sk2, _pk2) = keypair(2);
        let mut keys = ValidatorKeys::new();
        keys.insert("spiffe://v/1".into(), pk1);
        // v2 has NO registered key.
        keys.insert("spiffe://v/3".into(), keypair(3).1);
        let p = proof(vec![real_sig(&sk1, "spiffe://v/1", PH), real_sig(&sk2, "spiffe://v/2", PH)]);
        let o = verify_quorum_signed(&p, Some(PH), &keys);
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("no registered key")));
    }

    // ── device enrollment fusion (attested boot × cryptographic quorum) ────────────────────
    use watchdog_validator::attestation::{AttestationPolicy, BootProofRecord, StagePin, StageProof};

    fn vroot() -> String {
        format!("sha256:{}", "d".repeat(64))
    }

    fn boot(outcome: &str) -> BootProofRecord {
        let stage = |n: &str, h: String| StageProof {
            stage_name: n.into(), content_hash: h, verdict: "verified".into(), artifact_ref: String::new(),
        };
        BootProofRecord {
            outcome: outcome.into(),
            device_ref: "urn:srcos:device:d1".into(),
            boot_plan_ref: "p".into(),
            stage_proofs: vec![
                stage("firmware", format!("sha256:{}", "1".repeat(64))),
                stage("rootfs", vroot()),
            ],
            signature: None,
        }
    }
    fn boot_policy() -> AttestationPolicy {
        let b = boot("success");
        AttestationPolicy {
            expected_stages: b.stage_proofs.iter().map(|s| StagePin { stage_name: s.stage_name.clone(), content_hash: s.content_hash.clone() }).collect(),
            rootfs_stage: Some("rootfs".into()),
            rootfs_verity_root: Some(vroot()),
            require_signature: false,
        }
    }
    // a real 2-of-3 quorum signing the given enrollment payload hash.
    fn quorum_over(payload_hash: &str) -> (QuorumProof, ValidatorKeys) {
        let (sk1, pk1) = keypair(1);
        let (sk2, pk2) = keypair(2);
        let mut keys = ValidatorKeys::new();
        keys.insert("spiffe://v/1".into(), pk1);
        keys.insert("spiffe://v/2".into(), pk2);
        keys.insert("spiffe://v/3".into(), keypair(3).1);
        let p = QuorumProof {
            rule: "2of3-human".into(),
            validators: validators(),
            signed_payload_hash: payload_hash.into(),
            signatures: vec![real_sig(&sk1, "spiffe://v/1", payload_hash), real_sig(&sk2, "spiffe://v/2", payload_hash)],
        };
        (p, keys)
    }

    #[test]
    fn enroll_requires_both_attestation_and_quorum() {
        let b = boot("success");
        let ph = enrollment_payload_hash("urn:srcos:device:d1", &b);
        let (q, keys) = quorum_over(&ph);
        let o = enroll_device("urn:srcos:device:d1", &b, &boot_policy(), &q, &keys);
        assert!(o.enrolled, "{:?}", o.reasons);
    }

    #[test]
    fn enroll_rejects_unattested_boot_even_with_valid_quorum() {
        let b = boot("failure"); // boot did not succeed → attestation fails
        let ph = enrollment_payload_hash("urn:srcos:device:d1", &b);
        let (q, keys) = quorum_over(&ph);
        let o = enroll_device("urn:srcos:device:d1", &b, &boot_policy(), &q, &keys);
        assert!(!o.enrolled && o.reasons.iter().any(|r| r.starts_with("attestation:")));
    }

    #[test]
    fn enroll_rejects_quorum_bound_to_a_different_device() {
        // a valid quorum, but signed over ANOTHER device's payload — must not enroll this one.
        let b = boot("success");
        let other = enrollment_payload_hash("urn:srcos:device:OTHER", &b);
        let (q, keys) = quorum_over(&other);
        let o = enroll_device("urn:srcos:device:d1", &b, &boot_policy(), &q, &keys);
        assert!(!o.enrolled && o.reasons.iter().any(|r| r.starts_with("quorum:")));
    }

    // ── BLS macro-quorum over the k3s master triad ──────────────────────────────────────────
    const SR: &str = "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    fn bsig(master: &str) -> BlsSignature {
        BlsSignature { master: master.into(), sig: format!("bls:{}", "c".repeat(96)) }
    }
    fn triad_proof() -> BlsQuorumProof {
        BlsQuorumProof {
            rule: "2of3-master".into(),
            masters: vec!["did:web:m-a".into(), "did:web:m-b".into(), "did:web:m-c".into()],
            state_root: SR.into(),
            signatures: vec![bsig("did:web:m-a"), bsig("did:web:m-b")],
        }
    }

    #[test]
    fn bls_two_of_three_masters_pass() {
        assert!(verify_bls_quorum(&triad_proof(), Some(SR)).ok);
    }

    #[test]
    fn bls_below_threshold_fails() {
        let mut p = triad_proof();
        p.signatures.truncate(1); // only 1 of 3 signed
        assert!(!verify_bls_quorum(&p, Some(SR)).ok);
    }

    #[test]
    fn bls_unbound_quorum_rejected() {
        let other = "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
        let o = verify_bls_quorum(&triad_proof(), Some(other));
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("unbound")));
    }

    #[test]
    fn bls_unlisted_master_does_not_count() {
        let mut p = triad_proof();
        p.signatures[1] = bsig("did:web:INTRUDER");
        // only 1 listed master signed → below threshold 2
        assert!(!verify_bls_quorum(&p, Some(SR)).ok);
    }

    #[test]
    fn bls_duplicate_master_counts_once() {
        let mut p = triad_proof();
        p.signatures[1] = bsig("did:web:m-a"); // same master twice
        let o = verify_bls_quorum(&p, Some(SR));
        assert!(!o.ok && o.reasons.iter().any(|r| r.contains("duplicate")));
    }

    #[test]
    fn bls_malformed_sig_token_rejected() {
        let mut p = triad_proof();
        p.signatures[1].sig = "bls:notvalidhex".into();
        assert!(!verify_bls_quorum(&p, Some(SR)).ok);
    }

    #[test]
    fn bls_bad_state_root_rejected() {
        let mut p = triad_proof();
        p.state_root = "sha256:short".into();
        assert!(!verify_bls_quorum(&p, None).ok);
    }
}
