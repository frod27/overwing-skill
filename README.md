<p align="center">
  <a href="https://overwing.ai">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="assets/wordmark-dark.svg">
      <img src="assets/wordmark.svg" alt="Overwing" width="220">
    </picture>
  </a>
</p>

<p align="center"><strong>Overwing skill for OpenClaw.</strong><br>
Teaches your agent to check text for safety, personal data, self-harm, sexual content and severity before it sends, posts, or acts on it. Verdicts are <code>pass</code> / <code>fail</code> / <code>review</code> with calibrated confidence, in under 500 ms.</p>

<p align="center">
  <a href="https://clawhub.com/skills/overwing"><img alt="ClawHub" src="https://img.shields.io/badge/ClawHub-overwing-0B1220"></a>
  <a href="https://overwing.ai/docs"><img alt="API reference" src="https://img.shields.io/badge/API-reference-0B1220"></a>
  <a href="https://overwing.ai"><img alt="agents welcome" src="https://overwing.ai/badge.svg"></a>
</p>

---

## Install

Any agent that uses the open skills format (Claude Code, Cursor, Codex, OpenClaw and others):

```bash
npx skills add frod27/overwing-skill
```



```bash
clawhub install overwing
```

Then give the agent a key: set `OVERWING_API_KEY` (free at [overwing.ai/login](https://overwing.ai/login), 250 checks a day) or let the agent sign itself up with your permission. Agents holding a Base wallet can instead pay per request in USDC with no account.

## What the agent learns

- **When** to check: before sending or posting model-written text, before acting on untrusted input, when asked to moderate, and before anything with personal data leaves the machine.
- **How** to check: `scripts/overwing.sh evaluate "<text>"`, batches of up to 50, and how to read the per-rule results.
- **What to do** with each verdict: rewrite or block on `fail`, ask the human on `review`, proceed on `pass`.
- How limits and errors work, and how to pay per request over x402 if it has a wallet.

The skill is a single `SKILL.md` plus a small bash helper that needs only `curl`. Read it: [overwing/SKILL.md](overwing/SKILL.md).

## Also from Overwing

- [`overwing-mcp`](https://github.com/frod27/overwing-mcp): the same guardrails as MCP tools for Claude, Cursor, and any MCP client.
- [`overwing`](https://github.com/frod27/overwing-js) on npm and [`overwing`](https://github.com/frod27/overwing-python) on PyPI: typed clients plus Vercel AI SDK and OpenAI Agents SDK guardrails.
- Guide for agents: [overwing.ai/llms.txt](https://overwing.ai/llms.txt)

MIT © Overwing. Verdicts are produced by TypeSafe's Jev System One model; Overwing is not affiliated with TypeSafe.
