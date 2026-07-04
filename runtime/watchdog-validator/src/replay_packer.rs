use serde_json::json;

pub fn build_replay_envelope(call_id: &str, policy_decision_id: &str) -> serde_json::Value {
    json!({
        "id": format!("urn:srcos:replay:{}", call_id),
        "type": "ReplayEnvelope",
        "callId": call_id,
        "policyDecisionId": policy_decision_id,
        "determinismMode": "bounded"
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn replay_envelope_contains_expected_ids() {
        let env = build_replay_envelope("call_aa11bb22", "urn:srcos:decision:aa11bb22");
        assert_eq!(env["type"], "ReplayEnvelope");
        assert_eq!(env["callId"], "call_aa11bb22");
    }
}
