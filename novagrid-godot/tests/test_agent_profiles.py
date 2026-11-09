#!/usr/bin/env python3
"""Check NovaGrid Copilot agent profiles without third-party packages."""
from pathlib import Path
import re
import sys

repo = Path(__file__).resolve().parents[2]
agents_dir = repo / ".github" / "agents"
required = {
    "novagrid-director",
    "novagrid-game-designer",
    "novagrid-godot-engineer",
    "novagrid-visual-ux",
    "novagrid-audio-accessibility",
    "novagrid-android-performance",
    "novagrid-ads-privacy",
    "novagrid-qa",
    "novagrid-store-growth",
}

errors = []
found = {p.name.removesuffix(".agent.md") for p in agents_dir.glob("novagrid-*.agent.md")}
for name in sorted(required - found):
    errors.append(f"missing agent {name}")
for name in sorted(found - required):
    errors.append(f"unexpected unreviewed agent {name}")

for name in sorted(required & found):
    path = agents_dir / f"{name}.agent.md"
    content = path.read_text(encoding="utf-8")
    match = re.match(r"\A---\n(?P<meta>.*?)\n---\n(?P<body>.*)\Z", content, re.S)
    if not match:
        errors.append(f"{name}: invalid YAML frontmatter fence")
        continue
    meta, body = match.group("meta"), match.group("body")
    if not re.search(r"(?m)^description:\s*\S", meta):
        errors.append(f"{name}: missing description")
    if not re.search(r"(?m)^name:\s*\S", meta):
        errors.append(f"{name}: missing name")
    if "novagrid-godot/" not in body:
        errors.append(f"{name}: project scope not explicitly identified")
    if "QA" not in body:
        errors.append(f"{name}: missing quality gate")
    if len(content) > 30_000:
        errors.append(f"{name}: Copilot profile is over 30,000 characters")
for path in (repo / "novagrid-godot" / "AGENTS.md", repo / "novagrid-godot" / "AI-TEAM.md"):
    if not path.is_file():
        errors.append(f"missing {path.relative_to(repo)}")

if errors:
    print("\n".join("FAIL: " + e for e in errors), file=sys.stderr)
    sys.exit(1)
print(f"PASS: {len(required)} specialist NovaGrid agent profiles validated")
