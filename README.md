# loadout

A Claude Code plugin with useful skills to enhance your workflow.

## Installation

### Local development

```bash
claude --plugin-dir ./path/to/loadout
```

### From marketplace

```
/plugin install loadout
```

## Available Skills

### `/loadout:hello`

Greet the user with a personalized message.

```
/loadout:hello Alex
```

### `/loadout:summarize`

Summarize the current project or a specific file.

```
/loadout:summarize
/loadout:summarize src/index.ts
```

## Plugin Structure

```
loadout/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── skills/
│   ├── hello/
│   │   └── SKILL.md       # Greeting skill
│   └── summarize/
│       └── SKILL.md       # Summarization skill
├── .gitignore
└── README.md
```

## Development

To test changes locally:

```bash
claude --plugin-dir ./loadout
```

Reload after making changes:

```
/reload-plugins
```

## License

MIT
