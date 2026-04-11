#!/usr/bin/env python3
"""
install-hooks.py — Merge loadout hooks into a project's .claude/settings.json

Usage:
  python3 install-hooks.py --plugin-dir /path/to/loadout --project-dir /path/to/project --hooks hook1 hook2 ...

Prints a summary of what was added and the updated hooks block.
"""

import argparse
import json
import os
import shutil
import sys

# Hook definitions. Each entry maps hook name -> config block to merge into settings.json.
# Commands use relative .claude/hooks/scripts/ paths so settings.json is portable.
def build_catalog() -> dict:
    return {
        # ── Core hooks ─────────────────────────────────────────────────────────
        "scratch-capture": {
            "category": "core",
            "event": "PostToolUse",
            "description": "Remind to capture insights in scratch.md after Bash commands",
            "detection_tag": "scratch-reminder.sh",
            "entry": {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/scratch-reminder.sh",
                    }
                ],
            },
        },
        # ── Observability hooks ─────────────────────────────────────────────────
        "log-agent-spawn": {
            "category": "observability",
            "event": "PreToolUse",
            "description": "Log subagent spawns (type, description, bg) to .dev/loadout-test.log",
            "detection_tag": "log-agent-spawn.sh",
            "entry": {
                "matcher": "Agent",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/log-agent-spawn.sh",
                    }
                ],
            },
        },
        "log-agent-stop": {
            "category": "observability",
            "event": "SubagentStop",
            "description": "Log subagent completions (type, session ID) to .dev/loadout-test.log",
            "detection_tag": "log-agent-stop.sh",
            "entry": {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/log-agent-stop.sh",
                    }
                ],
            },
        },
        "log-skill-invoke": {
            "category": "observability",
            "event": "PreToolUse",
            "description": "Log skill invocations (name, args) to .dev/loadout-test.log",
            "detection_tag": "log-skill-invoke.sh",
            "entry": {
                "matcher": "Skill",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/log-skill-invoke.sh",
                    }
                ],
            },
        },
        "log-scratch-reminder": {
            "category": "observability",
            "event": "PostToolUse",
            "description": "Tee wrapper: run scratch-capture AND log to .dev/loadout-test.log",
            "detection_tag": "log-scratch-reminder.sh",
            "entry": {
                "matcher": "Bash",
                "hooks": [
                    {
                        "type": "command",
                        "command": "LOADOUT_PLUGIN_DIR=.claude bash .claude/hooks/scripts/log-scratch-reminder.sh",
                    }
                ],
            },
        },
        # ── Explore agent hooks ─────────────────────────────────────────────────
        "explore-ai-docs": {
            "category": "core",
            "event": "PreToolUse",
            "description": "Inject .ai-docs/ check instruction into Explore agent context",
            "detection_tag": "explore-ai-docs-context.json",
            "entry": {
                "matcher": "Agent",
                "hooks": [
                    {
                        "type": "command",
                        "command": "cat .claude/hooks/explore-ai-docs-context.json",
                    }
                ],
            },
        },
        # ── Quality hooks ───────────────────────────────────────────────────────
        "post-edit-lint": {
            "category": "quality",
            "event": "PostToolUse",
            "description": "Run project linting after file edits; lint command discovered from .ai-docs/",
            "detection_tag": "# hook:post-edit-lint",
            "entry": {
                "matcher": "Edit",
                "hooks": [
                    {
                        "type": "agent",
                        "prompt": (
                            "# hook:post-edit-lint\n"
                            "A file was just edited. Tool arguments: $ARGUMENTS\n\n"
                            "Your job:\n"
                            "1. Extract the file path from the arguments.\n"
                            "2. Scan .ai-docs/ frontmatter (Glob '.ai-docs/*.md') for files with patterns or "
                            "keywords related to 'lint-command', 'linting', 'commands', 'dev-commands', or "
                            "'build-commands'. Read only the relevant sections (use line ranges from frontmatter).\n"
                            "3. If found, run the lint command on the modified file using Bash and report results.\n"
                            "4. If not found in .ai-docs/, check for common config files "
                            "(package.json scripts, .eslintrc*, pyproject.toml, Makefile) and infer the lint command.\n"
                            "5. Report: list all lint errors/warnings with file:line references. "
                            "If clean, say 'Lint: clean'."
                        ),
                        "timeout": 120,
                    }
                ],
            },
        },
        "post-edit-simplify": {
            "category": "quality",
            "event": "PostToolUse",
            "description": "Report simplification opportunities after file edits based on .ai-docs/ patterns",
            "detection_tag": "# hook:post-edit-simplify",
            "entry": {
                "matcher": "Edit",
                "hooks": [
                    {
                        "type": "agent",
                        "prompt": (
                            "# hook:post-edit-simplify\n"
                            "A file was just edited. Tool arguments: $ARGUMENTS\n\n"
                            "Your job is to review the modified file for simplification opportunities.\n"
                            "1. Extract the file path from the arguments.\n"
                            "2. Read the file.\n"
                            "3. Scan .ai-docs/ frontmatter for patterns and anti-patterns relevant to this "
                            "file's language/domain. Read only the relevant sections (use line ranges from "
                            "frontmatter).\n"
                            "4. Identify: unnecessary complexity/nesting, violations of documented patterns, "
                            "documented anti-patterns present, redundant code, poor naming.\n"
                            "5. Do NOT edit the file. Report findings only as clear action items.\n"
                            "6. If no issues, say 'Simplify: nothing to do'."
                        ),
                        "timeout": 120,
                    }
                ],
            },
        },
    }


# All files required by each hook (hook name → list of (src_rel_to_plugin, dest_rel_to_project))
# Scripts are made executable automatically. All files are overwritten on install.
_S = os.path.join  # alias for brevity
HOOK_FILES = {
    "scratch-capture": [
        (_S("hooks", "scripts", "scratch-reminder.sh"),    _S(".claude", "hooks", "scripts", "scratch-reminder.sh")),
    ],
    "log-agent-spawn": [
        (_S("hooks", "scripts", "log-agent-spawn.sh"),     _S(".claude", "hooks", "scripts", "log-agent-spawn.sh")),
    ],
    "log-agent-stop": [
        (_S("hooks", "scripts", "log-agent-stop.sh"),      _S(".claude", "hooks", "scripts", "log-agent-stop.sh")),
    ],
    "log-skill-invoke": [
        (_S("hooks", "scripts", "log-skill-invoke.sh"),    _S(".claude", "hooks", "scripts", "log-skill-invoke.sh")),
    ],
    "log-scratch-reminder": [
        (_S("hooks", "scripts", "log-scratch-reminder.sh"), _S(".claude", "hooks", "scripts", "log-scratch-reminder.sh")),
        (_S("hooks", "scripts", "scratch-reminder.sh"),    _S(".claude", "hooks", "scripts", "scratch-reminder.sh")),
    ],
    "explore-ai-docs": [
        (_S("hooks", "explore-ai-docs-context.json"),      _S(".claude", "hooks", "explore-ai-docs-context.json")),
    ],
    "post-edit-lint": [],
    "post-edit-simplify": [],
}


def copy_hook_files(files_needed: list, plugin_dir: str, project_dir: str) -> list:
    """Copy hook files from plugin into the project, overwriting if present.
    Shell scripts (.sh) are made executable after copying."""
    copied = []
    for src_rel, dest_rel in files_needed:
        src = os.path.join(plugin_dir, src_rel)
        dst = os.path.join(project_dir, dest_rel)
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(src, dst)
        if dst.endswith(".sh"):
            os.chmod(dst, os.stat(dst).st_mode | 0o111)
        copied.append(dest_rel)
    return copied


# Hooks that must not coexist (log-* variants replace their core counterpart)
CONFLICTS = {
    "log-scratch-reminder": "scratch-capture",
}


def load_settings(settings_path: str) -> dict:
    if os.path.exists(settings_path):
        with open(settings_path) as f:
            return json.load(f)
    return {}


def already_installed(settings: dict, event: str, detection_tag: str) -> bool:
    """Check if a hook is already present in settings for the given event.

    Searches both the 'command' field (command-based hooks) and the 'prompt'
    field (agent-based hooks) for the detection_tag string.
    """
    hooks_block = settings.get("hooks", {})
    for entry in hooks_block.get(event, []):
        for h in entry.get("hooks", []):
            if detection_tag in h.get("command", ""):
                return True
            if detection_tag in h.get("prompt", ""):
                return True
    return False


def remove_conflicting(settings: dict, event: str, detection_tag: str):
    """Remove any existing hook entries whose command or prompt contains detection_tag."""
    hooks_block = settings.setdefault("hooks", {})
    event_list = hooks_block.get(event, [])
    hooks_block[event] = [
        entry for entry in event_list
        if not any(
            detection_tag in h.get("command", "") or detection_tag in h.get("prompt", "")
            for h in entry.get("hooks", [])
        )
    ]


def main():
    parser = argparse.ArgumentParser(description="Install loadout hooks into .claude/settings.json")
    parser.add_argument("--plugin-dir", required=True, help="Absolute path to the loadout plugin directory")
    parser.add_argument("--project-dir", required=True, help="Absolute path to the consuming project directory")
    parser.add_argument("--hooks", nargs="+", required=True, help="Hook names to install")
    parser.add_argument("--dry-run", action="store_true", help="Print what would change without writing")
    args = parser.parse_args()

    plugin_dir = os.path.abspath(args.plugin_dir)
    project_dir = os.path.abspath(args.project_dir)
    settings_path = os.path.join(project_dir, ".claude", "settings.json")
    catalog = build_catalog()

    # Validate hook names
    unknown = [h for h in args.hooks if h not in catalog]
    if unknown:
        print(f"ERROR: Unknown hook(s): {', '.join(unknown)}", file=sys.stderr)
        print(f"Available: {', '.join(catalog.keys())}", file=sys.stderr)
        sys.exit(1)

    # Check for conflicts between selected hooks
    selected = set(args.hooks)
    for obs_hook, core_hook in CONFLICTS.items():
        if obs_hook in selected and core_hook in selected:
            print(
                f"ERROR: Cannot install both '{obs_hook}' and '{core_hook}' — "
                f"'{obs_hook}' already includes '{core_hook}' behavior.",
                file=sys.stderr,
            )
            sys.exit(1)

    # Collect deduplicated set of files needed for selected hooks (by dest path)
    files_needed = []
    seen_files = set()
    for hook_name in args.hooks:
        for entry in HOOK_FILES.get(hook_name, []):
            if entry[1] not in seen_files:
                seen_files.add(entry[1])
                files_needed.append(entry)

    if args.dry_run:
        if files_needed:
            print("[DRY RUN] Would copy:")
            for _, dest_rel in files_needed:
                print(f"  + {dest_rel}")
            print()
    else:
        copy_hook_files(files_needed, plugin_dir, project_dir)

    settings = load_settings(settings_path)
    settings.setdefault("hooks", {})

    added = []
    skipped = []
    replaced = []

    for hook_name in args.hooks:
        hook = catalog[hook_name]
        event = hook["event"]
        # Unique tag used to detect if this hook is already installed.
        # Agent-based hooks carry a detection_tag; command-based hooks derive it
        # from the script basename.
        hook_entry = hook["entry"]["hooks"][0]
        _cmd_parts = hook_entry.get("command", "").split()
        detection_tag = hook.get(
            "detection_tag",
            _cmd_parts[-1] if _cmd_parts else "",
        )

        # Handle conflicts: if installing a log-* variant, remove the core variant
        if hook_name in CONFLICTS:
            core_name = CONFLICTS[hook_name]
            core_hook = catalog[core_name]
            core_entry = core_hook["entry"]["hooks"][0]
            _core_parts = core_entry.get("command", "").split()
            core_tag = core_hook.get(
                "detection_tag",
                _core_parts[-1] if _core_parts else "",
            )
            if already_installed(settings, event, core_tag):
                remove_conflicting(settings, event, core_tag)
                replaced.append((hook_name, core_name))

        # Skip if already installed
        if already_installed(settings, event, detection_tag):
            skipped.append(hook_name)
            continue

        settings["hooks"].setdefault(event, []).append(hook["entry"])
        added.append(hook_name)

    # Write result
    if not args.dry_run:
        os.makedirs(os.path.join(project_dir, ".claude"), exist_ok=True)
        with open(settings_path, "w") as f:
            json.dump(settings, f, indent=2)
            f.write("\n")

    # ── Summary ──────────────────────────────────────────────────────────────
    print(f"{'[DRY RUN] ' if args.dry_run else ''}Settings: {settings_path}")
    print()

    if not args.dry_run and files_needed:
        print("Copied:")
        for _, dest_rel in files_needed:
            print(f"  + {dest_rel}")
        print()

    if added:
        print("Added:")
        for name in added:
            h = catalog[name]
            print(f"  + {name}  ({h['event']})  — {h['description']}")

    if replaced:
        print("Replaced (log variant includes core behavior):")
        for obs, core in replaced:
            print(f"  ~ {core} → {obs}")

    if skipped:
        print("Already installed (skipped):")
        for name in skipped:
            print(f"  = {name}")

    if not added and not replaced:
        print("Nothing to do — all selected hooks already installed.")
        return

    print()
    print("Updated hooks block:")
    print(json.dumps({"hooks": settings["hooks"]}, indent=2))


if __name__ == "__main__":
    main()
