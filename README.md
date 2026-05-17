# protect-against-force-pushes

Mass-apply GitHub rulesets that block force pushes and branch deletions across every repository you administer.

If an AI agent, CLI workflow, or bulk script can touch all your repos, one bad command can too. This script adds a server-side safety rail behind that power.

## AI safety for GitHub admins

More teams are letting AI work inside terminals, CI systems, and repository automation. That increases speed, but it also increases the chance of high-impact mistakes being executed at machine speed.

This project is built for that exact risk.

It helps protect your GitHub estate when:

- an AI coding agent runs `gh` with repo admin permissions
- an LLM-generated script is accepted too quickly
- an automation pipeline gets broad GitHub access
- a human operator delegates sensitive admin work to AI-assisted tooling

The core idea is simple: do not rely on the caller to be careful. Put protection on the GitHub side.

## What it protects

The script creates a repository ruleset with:

- `non_fast_forward` to block force pushes
- `deletion` to block branch deletion

It targets all branches and works as an idempotent enforcement pass across a user or organization.

That means even if an AI-driven workflow attempts a destructive branch rewrite, GitHub can reject it before damage spreads.

## Why this is useful

The problem is not just humans making mistakes. The problem is high-privilege automation operating at scale:

- shell scripts
- CI jobs
- internal tooling
- rushed admin work with `gh`
- AI agents using a terminal and a GitHub token

This project does not "detect AI" or "block AI." It does something more useful: it limits what AI-assisted admin workflows can break by enforcing branch safety at the platform layer.

## Quick start

### Requirements

- `gh` installed
- authenticated via `gh auth login`
- admin rights on the target repositories

### Run

```bash
chmod +x protect-repos.sh
./protect-repos.sh my-org
```

Dry run first if you want to inspect behavior:

```bash
./protect-repos.sh --dry-run my-org
```

## What the script does

1. Lists up to 1000 non-archived repositories for the given user or org
2. Filters to repos where your GitHub account can administer settings
3. Checks whether the ruleset already exists
4. Creates it only when missing

That makes repeated runs safe and useful for audits.

## Example output

```text
Repo: acme/api
  OK: ruleset already exists: 123456

Repo: acme/frontend
  OK: ruleset created: 789012
```

## Why server-side rules matter

Local discipline is not enough when automation has broad permission.

You can trust developers.
You can review prompts.
You can still lose branch history with one bad AI-generated action.

Rulesets are valuable because GitHub enforces them even when the caller is a CLI, a script, or an automated agent.

That is the key AI protection property here:

- the model can be wrong
- the script can be unsafe
- the token can still be real
- GitHub policy remains the final control

## Scope and limits

This is a guardrail, not a full security program.

It helps against:

- accidental force pushes
- destructive admin scripts
- unsafe automation defaults
- overpowered AI-assisted workflows
- AI agents acting with excessive repository permissions

It does not replace:

- least-privilege tokens
- sandboxing for AI agents
- required reviews
- status checks
- audit logging
- repository ownership controls

## Files

- [protect-repos.sh](./protect-repos.sh): CLI script
- [ARTICLE.md](./ARTICLE.md): short explainer article

## Next improvements

- audit mode with JSON or CSV output
- update mode for existing but mismatched rulesets
- org-wide policy bundles beyond force-push protection
