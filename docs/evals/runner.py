"""
Meta-eval for the claude-code-master-prompt system.
Validates structural consistency of CLAUDE.md, agent cartridges, and rules.
Run: python docs/evals/runner.py
Pass threshold: >=0.80 (20/25 checks passing)
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent.parent
AGENTS_DIR = ROOT / "agents"
RULES_DIR = ROOT / "rules"
CLAUDE_MD = ROOT / "CLAUDE.md"

REQUIRED_AGENT_SLOTS = [
    "Slot 1", "Slot 2", "Slot 3", "Slot 4", "Slot 5",
    "Slot 6", "Slot 7", "Slot 8", "Slot 9", "Slot 10",
]

REQUIRED_RULES_FILES = [
    "workflows.md", "codex-routing.md", "sprint-status.md",
    "hooks.md", "self-improvement.md", "prompt-repo.md",
]

ROUTING_TABLE_AGENTS = [
    "architect", "llmops-expert", "backend-expert", "backend-tester",
    "frontend-expert", "devops-expert", "vercel-deployer", "adversarial",
    "validate", "researcher", "scraper", "drafter",
    "prompt-engineer", "eval-writer", "sme-reviewer",
    "session-improver", "system-curator",
]

HAIKU_AGENTS = {"drafter", "validate"}
SONNET_AGENTS = {
    "architect", "llmops-expert", "backend-expert", "backend-tester",
    "frontend-expert", "devops-expert", "vercel-deployer", "adversarial",
    "researcher", "scraper", "prompt-engineer", "eval-writer",
    "sme-reviewer", "session-improver", "system-curator",
}


def check(name: str, result: bool, detail: str = "") -> tuple[bool, str]:
    status = "PASS" if result else "FAIL"
    msg = f"  [{status}] {name}"
    if detail and not result:
        msg += f"\n         {detail}"
    return result, msg


def run_checks() -> list[tuple[bool, str]]:
    results = []

    # 1. CLAUDE.md exists
    results.append(check("CLAUDE.md exists", CLAUDE_MD.exists()))

    # 2. CLAUDE.md line count <= 120
    if CLAUDE_MD.exists():
        lines = len(CLAUDE_MD.read_text(encoding="utf-8").splitlines())
        results.append(check(
            f"CLAUDE.md line count <= 120 (actual: {lines})",
            lines <= 120,
            f"CLAUDE.md has {lines} lines — trim to <=120"
        ))
    else:
        results.append(check("CLAUDE.md line count", False, "file missing"))

    # 3. All required rules files exist
    for fname in REQUIRED_RULES_FILES:
        p = RULES_DIR / fname
        results.append(check(f"rules/{fname} exists", p.exists()))

    # 4. All routing table agents have cartridge files
    for agent in ROUTING_TABLE_AGENTS:
        p = AGENTS_DIR / f"{agent}.md"
        results.append(check(f"agents/{agent}.md exists", p.exists()))

    # 5. Haiku agents have correct model in frontmatter
    for agent in HAIKU_AGENTS:
        p = AGENTS_DIR / f"{agent}.md"
        if p.exists():
            content = p.read_text(encoding="utf-8")
            has_haiku = "haiku" in content[:300].lower()
            results.append(check(
                f"{agent}.md uses haiku model",
                has_haiku,
                f"Expected 'haiku' in frontmatter of {agent}.md"
            ))

    # 6. Sonnet agents do NOT accidentally use haiku
    # (sample check — only check 3 key ones to keep test count manageable)
    for agent in ["llmops-expert", "backend-expert", "adversarial"]:
        p = AGENTS_DIR / f"{agent}.md"
        if p.exists():
            frontmatter = p.read_text(encoding="utf-8")[:300].lower()
            # These should have sonnet or no model override (default = sonnet)
            uses_haiku_in_fm = bool(re.search(r"^model:.*haiku", frontmatter, re.MULTILINE))
            results.append(check(
                f"{agent}.md does not force haiku",
                not uses_haiku_in_fm,
                f"{agent}.md frontmatter sets haiku — should be sonnet"
            ))

    # 7. Each agent cartridge has all 10 slots
    for agent in ["drafter", "llmops-expert", "backend-expert"]:
        p = AGENTS_DIR / f"{agent}.md"
        if p.exists():
            content = p.read_text(encoding="utf-8")
            missing = [s for s in REQUIRED_AGENT_SLOTS if s not in content]
            results.append(check(
                f"{agent}.md has all 10 slots",
                not missing,
                f"Missing: {missing}"
            ))

    # 8. workflows.md contains parallel agent rules
    wf = RULES_DIR / "workflows.md"
    if wf.exists():
        content = wf.read_text(encoding="utf-8")
        results.append(check(
            "workflows.md has parallel agent min-3 rule",
            "Minimum 3 agents" in content or "min 3" in content.lower()
        ))
        results.append(check(
            "workflows.md has model routing section",
            "## Model routing" in content
        ))
        results.append(check(
            "workflows.md has prompt-by-reference rule",
            "reference" in content.lower() and "300 token" in content.lower()
        ))

    # 9. self-improvement.md has derived rules table
    si = RULES_DIR / "self-improvement.md"
    if si.exists():
        content = si.read_text(encoding="utf-8")
        results.append(check(
            "self-improvement.md has derived rules table",
            "Rules Derived from Self-Improvement Sessions" in content
        ))
        results.append(check(
            "self-improvement.md has incident evidence pattern",
            "Incident" in content
        ))

    return results


def main() -> int:
    print("\n=== Master Prompt Meta-Eval ===\n")
    results = run_checks()

    passed = sum(1 for ok, _ in results if ok)
    total = len(results)
    score = passed / total

    for _, msg in results:
        print(msg)

    print(f"\nScore: {passed}/{total} = {score:.2f}")
    threshold = 0.80
    if score >= threshold:
        print(f"PASS (>= {threshold})")
        return 0
    else:
        print(f"FAIL (< {threshold})")
        return 1


if __name__ == "__main__":
    sys.exit(main())
