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
        "prompt-doc-scan": {
            "category": "core",
            "event": "UserPromptSubmit",
            "description": "Scan .ai-docs/ on each prompt, inject relevant docs into context",
            "entry": {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/prompt-scan-docs.sh",
                    }
                ],
            },
        },
        "plan-rescan": {
            "category": "core",
            "event": "SubagentStop",
            "description": "Re-scan .ai-docs/ after Explore/Plan agents complete",
            "entry": {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash .claude/hooks/scripts/plan-rescan-docs.sh",
                    }
                ],
            },
        },
        "scratch-capture": {
            "category": "core",
            "event": "PostToolUse",
            "description": "Remind to capture insights in scratch.md after Bash commands",
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
        "log-doc-scan": {
            "category": "observability",
            "event": "UserPromptSubmit",
            "description": "Tee wrapper: run prompt-doc-scan AND log output to .dev/loadout-test.log",
            "entry": {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "LOADOUT_PLUGIN_DIR=.claude bash .claude/hooks/scripts/log-doc-scan.sh",
                    }
                ],
            },
        },
        "log-plan-rescan": {
            "category": "observability",
            "event": "SubagentStop",
            "description": "Tee wrapper: run plan-rescan AND log output to .dev/loadout-test.log",
            "entry": {
                "matcher": "",
                "hooks": [
                    {
                        "type": "command",
                        "command": "LOADOUT_PLUGIN_DIR=.claude bash .claude/hooks/scripts/log-plan-rescan.sh",
                    }
                ],
            },
        },
        "log-scratch-reminder": {
            "category": "observability",
            "event": "PostToolUse",
            "description": "Tee wrapper: run scratch-capture AND log to .dev/loadout-test.log",
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
    }


# Scripts required by each hook (hook name → list of script filenames)
HOOK_SCRIPTS = {
    "prompt-doc-scan":    ["prompt-scan-docs.sh"],
    "plan-rescan":        ["plan-rescan-docs.sh"],
    "scratch-capture":    ["scratch-reminder.sh"],
    "log-agent-spawn":    ["log-agent-spawn.sh"],
    "log-agent-stop":     ["log-agent-stop.sh"],
    "log-skill-invoke":   ["log-skill-invoke.sh"],
    "log-doc-scan":       ["log-doc-scan.sh", "prompt-scan-docs.sh"],
    "log-plan-rescan":    ["log-plan-rescan.sh", "plan-rescan-docs.sh"],
    "log-scratch-reminder": ["log-scratch-reminder.sh", "scratch-reminder.sh"],
}


def copy_scripts(scripts_needed: list, plugin_dir: str, project_dir: str) -> list:
    """Copy hook scripts from plugin into project's .claude/hooks/scripts/."""
    dest_dir = os.path.join(project_dir, ".claude", "hooks", "scripts")
    os.makedirs(dest_dir, exist_ok=True)
    copied = []
    for script in scripts_needed:
        src = os.path.join(plugin_dir, "hooks", "scripts", script)
        dst = os.path.join(dest_dir, script)
        shutil.copy2(src, dst)
        os.chmod(dst, os.stat(dst).st_mode | 0o111)
        copied.append(script)
    return copied


# Hooks that must not coexist (log-* variants replace their core counterpart)
CONFLICTS = {
    "log-doc-scan": "prompt-doc-scan",
    "log-plan-rescan": "plan-rescan",
    "log-scratch-reminder": "scratch-capture",
}


def load_settings(settings_path: str) -> dict:
    if os.path.exists(settings_path):
        with open(settings_path) as f:
            return json.load(f)
    return {}


def already_installed(settings: dict, event: str, command_fragment: str) -> bool:
    """Check if a hook command is already present in settings for the given event."""
    hooks_block = settings.get("hooks", {})
    for entry in hooks_block.get(event, []):
        for h in entry.get("hooks", []):
            if command_fragment in h.get("command", ""):
                return True
    return False


def remove_conflicting(settings: dict, event: str, command_fragment: str):
    """Remove any existing hook entries whose command contains command_fragment."""
    hooks_block = settings.setdefault("hooks", {})
    event_list = hooks_block.get(event, [])
    hooks_block[event] = [
        entry for entry in event_list
        if not any(command_fragment in h.get("command", "") for h in entry.get("hooks", []))
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

    # Collect deduplicated set of scripts needed for selected hooks
    scripts_needed = []
    seen = set()
    for hook_name in args.hooks:
        for script in HOOK_SCRIPTS.get(hook_name, []):
            if script not in seen:
                seen.add(script)
                scripts_needed.append(script)

    if args.dry_run:
        if scripts_needed:
            print("[DRY RUN] Would copy to .claude/hooks/scripts/:")
            for script in scripts_needed:
                print(f"  + {script}")
            print()
    else:
        copied = copy_scripts(scripts_needed, plugin_dir, project_dir)

    settings = load_settings(settings_path)
    settings.setdefault("hooks", {})

    added = []
    skipped = []
    replaced = []

    for hook_name in args.hooks:
        hook = catalog[hook_name]
        event = hook["event"]
        # Unique fragment used to detect if this hook is already installed
        script_basename = hook["entry"]["hooks"][0]["command"].split()[-1]

        # Handle conflicts: if installing a log-* variant, remove the core variant
        if hook_name in CONFLICTS:
            core_name = CONFLICTS[hook_name]
            core_hook = catalog[core_name]
            core_fragment = core_hook["entry"]["hooks"][0]["command"].split()[-1]
            if already_installed(settings, event, core_fragment):
                remove_conflicting(settings, event, core_fragment)
                replaced.append((hook_name, core_name))

        # Skip if already installed
        if already_installed(settings, event, script_basename):
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

    if not args.dry_run and scripts_needed:
        print("Copied to .claude/hooks/scripts/:")
        for script in scripts_needed:
            print(f"  + {script}")
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
