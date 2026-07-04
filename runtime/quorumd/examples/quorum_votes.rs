use quorumd::{aggregate, Vote};

fn main() {
    let votes = vec![
        Vote { signer: "validator@v1".into(), verdict: "reseal_resume".into() },
        Vote { signer: "validator@v2".into(), verdict: "reseal_resume".into() },
        Vote { signer: "watchdog@w1".into(), verdict: "terminate".into() },
    ];

    let verdict = aggregate(&votes).unwrap_or_else(|| "defer".to_string());
    println!("majority_verdict={}", verdict);
}
