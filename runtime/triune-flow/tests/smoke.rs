use serde_json::Value;
use std::path::PathBuf;
use std::process::Command;

#[test]
fn triune_flow_emits_expected_shape() {
    let bin = env!("CARGO_BIN_EXE_triune-flow");
    let output = Command::new(bin)
        .output()
        .expect("triune-flow binary should run");
    assert!(output.status.success(), "binary exited unsuccessfully");

    let actual: Value = serde_json::from_slice(&output.stdout).expect("stdout should be valid JSON");

    let manifest_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"));
    let sample_path = manifest_dir.join("output.sample.json");
    let sample: Value = serde_json::from_slice(
        &std::fs::read(sample_path).expect("sample output should exist"),
    )
    .expect("sample output should be valid JSON");

    assert_eq!(actual["context"]["plane"], sample["context"]["plane"]);
    assert_eq!(actual["authorization"]["grant_id"], sample["authorization"]["grant_id"]);
    assert_eq!(actual["quarantine"]["isolation_mode"], sample["quarantine"]["isolation_mode"]);
    assert_eq!(actual["quorum"]["majority_verdict"], sample["quorum"]["majority_verdict"]);

    assert!(actual["anchor"]["entry_hash"].as_str().unwrap().starts_with("sha256:"));
    assert!(actual["anchor"]["root"].as_str().unwrap().starts_with("sha256:"));
}
