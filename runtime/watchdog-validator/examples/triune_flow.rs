use serde_json::json;
use watchdog_validator::{build_anchor_payload, build_quarantine_plan};

fn main() {
    let subject_id = "urn:srcos:session:s001";
    let trigger_type = "egress_policy_violation";

    let plan = build_quarantine_plan(subject_id);
    let anchor_payload = build_anchor_payload(subject_id, trigger_type);

    let packet = json!({
        "trigger": {
            "subject_id": subject_id,
            "trigger_type": trigger_type
        },
        "quarantine_plan": plan,
        "anchor_payload": anchor_payload,
        "next": ["validator-review"]
    });

    println!("{}", serde_json::to_string_pretty(&packet).unwrap());
}
