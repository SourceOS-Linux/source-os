use cap_checker::{authorize, CapabilityGrant, OperationKind, OperationRequest};
use quorumd::{aggregate, Vote};
use serde_json::json;
use triune_anchor::append;
use triune_ctx::{stamp_context, verify_context, TriunePlane};
use watchdog_validator::{build_anchor_payload, build_quarantine_plan};

fn main() {
    let ctx = stamp_context(
        TriunePlane::Audit,
        "agent.watchdog.validator",
        "sha256:deadbeef",
        "sha256:cafebabe",
    );
    verify_context(&ctx).expect("context should verify");

    let request = OperationRequest {
        operation: OperationKind::Tag,
        target_id: "urn:srcos:session:s001".into(),
        target_labels: vec!["dag::mutable".into()],
    };
    let grants = vec![CapabilityGrant {
        id: "cap-1".into(),
        subject: "agent.watchdog.validator".into(),
        operations: vec![OperationKind::Tag],
        labels: vec!["dag::mutable".into()],
    }];
    let grant_id = authorize(&request, &grants).expect("capability should authorize");

    let quarantine = build_quarantine_plan("urn:srcos:session:s001");
    let anchor_payload = build_anchor_payload("urn:srcos:session:s001", "egress_policy_violation");

    let anchor_path = std::env::temp_dir().join("triune-flow-audit.ndjson");
    let anchor = append(
        &anchor_path,
        "quarantine-trigger",
        Some("urn:srcos:session:s001"),
        anchor_payload.clone(),
    )
    .expect("anchor append should succeed");

    let votes = vec![
        Vote { signer: "validator@v1".into(), verdict: "reseal_resume".into() },
        Vote { signer: "validator@v2".into(), verdict: "reseal_resume".into() },
        Vote { signer: "watchdog@w1".into(), verdict: "terminate".into() },
    ];
    let verdict = aggregate(&votes).unwrap_or_else(|| "defer".to_string());

    let packet = json!({
        "context": {
            "call_id": ctx.call_id,
            "plane": ctx.plane,
            "policy_digest": ctx.attestation.policy_digest,
        },
        "authorization": {
            "grant_id": grant_id,
            "target_id": request.target_id,
        },
        "quarantine": quarantine,
        "anchor": {
            "entry_hash": anchor.entry_hash,
            "root": anchor.root,
            "path": anchor_path,
        },
        "quorum": {
            "votes": votes,
            "majority_verdict": verdict,
        }
    });

    println!("{}", serde_json::to_string_pretty(&packet).unwrap());
}
