# Why Force-Push Protection Matters in the Age of `gh` and AI Automation

GitHub's CLI is extremely capable. With a valid token and admin access, a single command or script can modify settings, rewrite workflow state, or push policy changes across many repositories in minutes.

That power is exactly why repository guardrails matter.

## The real problem

The risk is not "AI" by itself. The risk is high-privilege automation.

Today that automation may be:

- a shell script
- a CI job
- an internal tool
- a developer using `gh` in a hurry
- an AI agent that has access to the terminal and a GitHub token

All of those can make the same class of mistake: destructive branch operations at scale.

## What this project does

This project applies a GitHub repository ruleset to every repository you administer and blocks:

- force pushes
- branch deletions

That means even if a script or agent attempts a dangerous history rewrite, GitHub rejects it at the policy layer.

## Why that is valuable

Good security controls do not rely on perfect behavior from tools or people. They assume mistakes will happen and limit the damage.

Blocking force pushes is a simple example of that philosophy:

- history is harder to destroy
- recovery effort drops
- automation mistakes become visible faster
- a compromised or over-scoped token has less room to cause irreversible damage

## Does this "protect against AI"?

Not in the marketing sense, and it should not be described that way.

A better claim is:

> This reduces the blast radius of AI-assisted or CLI-based GitHub administration by enforcing server-side branch safety rules.

That is narrower, but technically correct.

## Why `gh` can be dangerous

`gh` is not dangerous because it is bad. It is dangerous because it is effective.

If you combine:

- admin permissions
- broad token scopes
- bulk scripting
- weak review around automation

then the CLI becomes a fast path to large mistakes.

The answer is not to avoid the CLI. The answer is to put policy behind it.

## Bottom line

If humans, scripts, or AI agents can operate your GitHub estate through `gh`, repository rulesets are one of the cheapest high-value controls you can add.

They do not remove risk, but they materially reduce how much damage a bad command can do.
