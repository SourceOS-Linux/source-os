#!/usr/bin/env python3
"""Agent-S GUI test driver for SourceOS images.

Drives whatever is on the current display (the QEMU guest, shown full-screen on
an Xvfb display the VM window fills) with Agent-S, to verify a SourceOS image
behaves like a usable desktop. Screenshots + actions go through pyautogui, which
is exactly Agent-S's interaction model.

Run inside the harness (harness.sh), which sets up the display and boots the VM.

Env:
  ANTHROPIC_API_KEY / OPENAI_API_KEY  main-model key
  AS_PROVIDER   main model provider (default: anthropic)
  AS_MODEL      main model (default: claude-sonnet-4-6)
  AS_GROUND_URL grounding model endpoint (UI-TARS via vLLM/TGI)   [required for S3]
  AS_GROUND_MODEL / AS_GROUND_WIDTH / AS_GROUND_HEIGHT
  AS_TASK       instruction (default: verify the GNOME desktop)
  AS_MAX_STEPS  step cap (default: 25)
  AS_ARTIFACTS  dir for screenshots + result.json (default: ./artifacts)

Exit code 0 = agent reported the task complete; non-zero = failure/timeout.
"""
import io
import os
import sys
import json
import time
import pathlib

PROVIDER = os.environ.get("AS_PROVIDER", "anthropic")
MODEL = os.environ.get("AS_MODEL", "claude-sonnet-4-6")
GROUND_URL = os.environ.get("AS_GROUND_URL", "")
GROUND_MODEL = os.environ.get("AS_GROUND_MODEL", "ui-tars-1.5-7b")
GROUND_W = int(os.environ.get("AS_GROUND_WIDTH", "1920"))
GROUND_H = int(os.environ.get("AS_GROUND_HEIGHT", "1080"))
MAX_STEPS = int(os.environ.get("AS_MAX_STEPS", "25"))
ARTIFACTS = pathlib.Path(os.environ.get("AS_ARTIFACTS", "./artifacts"))
TASK = os.environ.get(
    "AS_TASK",
    "This is a freshly booted SourceOS GNOME desktop. Confirm the desktop is "
    "usable: open the Activities overview, launch the Files application, and "
    "verify a window opens. When you have confirmed it works, you are done.",
)


def main() -> int:
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    if not GROUND_URL:
        print("ERROR: AS_GROUND_URL not set — Agent-S S3 needs a grounding model "
              "endpoint (e.g. UI-TARS on vLLM). See tests/agent-s/README.md.",
              file=sys.stderr)
        return 2

    import pyautogui
    from gui_agents.s3.agents.agent_s import AgentS3
    from gui_agents.s3.agents.grounding import OSWorldACI

    engine_params = {"engine_type": PROVIDER, "model": MODEL}
    engine_params_for_grounding = {
        "engine_type": "openai",  # OpenAI-compatible endpoint (vLLM/TGI) for UI-TARS
        "base_url": GROUND_URL,
        "model": GROUND_MODEL,
    }

    grounding = OSWorldACI(
        platform="linux",
        engine_params_for_generation=engine_params,
        engine_params_for_grounding=engine_params_for_grounding,
        width=GROUND_W,
        height=GROUND_H,
    )
    agent = AgentS3(engine_params, grounding, platform="linux")

    result = {"task": TASK, "steps": 0, "done": False, "error": None}
    try:
        for step in range(1, MAX_STEPS + 1):
            result["steps"] = step
            shot = pyautogui.screenshot()
            buf = io.BytesIO()
            shot.save(buf, format="PNG")
            shot.save(ARTIFACTS / f"step-{step:02d}.png")
            obs = {"screenshot": buf.getvalue()}

            info, actions = agent.predict(instruction=TASK, observation=obs)

            for act in actions:
                if "DONE" in act or "done" in act:
                    result["done"] = True
                    break
                if "FAIL" in act:
                    result["error"] = "agent reported FAIL"
                    break
                exec(act)  # Agent-S action = python (pyautogui / ACI calls)
                time.sleep(1.0)
            if result["done"] or result["error"]:
                break
    except Exception as e:  # noqa: BLE001 — report any driver error as failure
        result["error"] = repr(e)

    (ARTIFACTS / "result.json").write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))
    return 0 if result["done"] and not result["error"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
