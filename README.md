# ty

TY's planning and coordination skills plus their worker/verifier/investigator agents, packaged as a Claude Code plugin.

## Skills

`ty-planner`, `ty-coordinator`

## Agents

`ty-design-critic`, `ty-metrics-investigator`, `ty-verifier`, `ty-worker`

## Installation

### Project settings (recommended for teams)

Add to your project's `.claude/settings.json`:

```json
{
  "extraKnownMarketplaces": {
    "ty": {
      "source": {
        "source": "github",
        "repo": "thanhpp/ty"
      }
    }
  },
  "enabledPlugins": {
    "ty@ty": true
  }
}
```

Claude Code will auto-register the marketplace when the project folder is trusted. To install manually:

```bash
claude plugin install ty@ty --scope project
```

### Local development / testing

```bash
claude --plugin-dir .
```

## Releasing

```bash
scripts/release.sh [patch|minor|major]   # default: patch
```

Bumps the version in `.claude-plugin/plugin.json`, commits to `main`, pushes, and creates a GitHub release tag. Must be run from a clean `main` branch with no unpushed commits.
