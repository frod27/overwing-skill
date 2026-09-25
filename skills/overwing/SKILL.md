---
name: overwing
description: Check any text for safety, personal data, confidential leaks, self-harm, sexual content and severity before you send it, act on it, or show it to a person, and identify any User-Agent string against Overwing Atlas, a registry of 241 AI crawlers, fetchers and browser agents with verification classes. One API call returns a verdict, a recommended action (block, redact, review, allow) and per-rule results with calibrated confidence in under 500 ms. Pass context (who the recipient is, which channel, whether you own the data) so personal data the recipient already owns is not flagged. Use for moderating model output, screening incoming messages, or scoring drafts. Works with an API key or, for wallet-holding agents, pay-per-request in USDC with no account.
homepage: https://overwing.ai
metadata:
  {
    "openclaw":
      {
        "emoji": "🪽",
        "homepage": "https://overwing.ai",
        "primaryEnv": "OVERWING_API_KEY",
        "requires": { "bins": ["curl"] },
      },
  }
---

# Overwing

Overwing scores text and returns a typed verdict plus one word to act on. Use it as a guardrail: before
you send a reply, post content, act on an untrusted message, or hand something
to a person, evaluate it. Read `recommended_action`: `block` means do not send,
`redact` means remove the flagged content and check again, `review` means ask
your human or take the cautious path, `allow` means go ahead.

## When to use this skill

- You are about to send, post, or store text that a model (including you) wrote.
- You received text from an untrusted source and are about to act on it.
- Your human asks you to moderate, screen, or check content.
- You want to check for personal data (emails, phone numbers, addresses, IDs)
  before something leaves the machine.

Do not use it for trivial system messages, code, or text your human wrote and
explicitly asked you to send unchanged.

## Setup (once)

The key lives in `OVERWING_API_KEY`. If it is not set:

1. Ask your human for a key from https://overwing.ai/login (free, 250 checks a day).
2. Or, with your human's permission, sign up in one call and store the key:

```bash
{baseDir}/scripts/overwing.sh signup you@example.com 'a-password-of-12-or-more'
```

The response contains `api_key`. Put it in `OVERWING_API_KEY` (or `skills.entries.overwing.apiKey` in openclaw.json). Never print the key back into chat. Accounts made this way start at 50 checks a day until the email is confirmed.

If you hold a funded wallet on Base and have no key, see "Paying per request" below.

## Evaluate one text

```bash
{baseDir}/scripts/overwing.sh evaluate "The text to check"
```

Returns JSON:

```json
{ "id": "eval_…", "verdict": "fail", "recommended_action": "redact", "aggregate_score": 0.82, "confidence": 0.97, "latency_ms": 251,
  "results": [ { "rule": "pii_detected", "type": "noul", "answer": true, "probability": 0.99, "confidence": 0.98, "verdict": "fail", "action": "redact" }, … ] }
```

How to act on it. `recommended_action` is the one field to branch on:

| recommended_action | meaning | what to do |
| --- | --- | --- |
| `block` | a rule with action `block` failed | do not send; tell your human what was flagged and why, or rewrite from scratch |
| `redact` | only rules with action `redact` failed (personal data, usually) | remove the flagged content, then evaluate the new text again |
| `review` | no rule failed outright, but one was unsure, or a `review` rule failed | ask your human, or take the safer option |
| `allow` | nothing tripped | proceed |

`verdict` is the coarser signal (`fail` / `review` / `pass`). `results[].rule` names each rule and `results[].action` says what that rule asks for when it fails. `confidence` is 0 to 1. The `content-safety` set has `toxicity`, `pii_detected` (redact), `self_harm`, `sexual_content`, `severity`.

Pass a different rule set with `--rule-set <slug>`; the default is `content-safety`.

## Tell it who the message is for (context)

Personal data is not always a leak: a customer's own phone number in a reply to that customer is fine. Pass what you know as `--context` JSON and use the `outbound-message` rule set, whose rules read it:

```bash
{baseDir}/scripts/overwing.sh evaluate --rule-set outbound-message \
  --context '{"recipient":"the customer who asked for a callback","channel":"email","owns_contact_info":true,"sender":"support agent"}' \
  "Hi Dana, I can call you at 555-0142 tomorrow at 10."
```

Useful keys: `recipient` (who will read it), `channel` (email, chat, public post, sms), `owns_contact_info` (true if the recipient already owns the personal data in the text), `sender`, `purpose`. Any JSON object up to 8 KB works; the rules quote it back in their reasoning. The `outbound-message` set adds `unauthorized_pii` (redact) and `confidential_leak` (block: internal notes, credentials, pricing not meant for this recipient) to the safety checks. Without context, treat every personal detail as unauthorized and redact it.

## Evaluate many texts at once

Up to 50 per call, one line of JSON per item on stdin:

```bash
printf '%s\n' '{"id":"a","input":"first"}' '{"id":"b","input":"second"}' | {baseDir}/scripts/overwing.sh batch
```

Returns a summary plus per-item verdicts and recommended actions. Each item counts as one check. `--context` applies to every item; an item can carry its own `"context": {…}` to override it.

## Limits and errors

- Free accounts: 250 checks a day and 30 a minute; paid plans raise both. Responses carry `X-RateLimit-Remaining` and `X-Burst-Remaining`.
- HTTP 429 means wait for the seconds in `Retry-After`, or tell your human the daily limit is reached (they can upgrade or buy prepaid credits at https://overwing.ai/dashboard/billing).
- HTTP 401 means the key is missing or revoked. Ask your human; do not retry blindly.
- HTTP 502 means the evaluation engine did not answer; retry once after a few seconds.
- Every error body is `{"error": "human readable message"}`.

Check remaining quota:

```bash
{baseDir}/scripts/overwing.sh usage
```

## Paying per request (agents with a wallet, no account)

`POST https://overwing.ai/api/x402/evaluate` takes the same body as the normal endpoint and is paid per call in USDC on Base (about $0.002 each) over the x402 protocol. The first response is HTTP 402 with the payment requirements; sign them with an x402 client (for example `x402-fetch` in Node) and resend with the `X-PAYMENT` header. `GET` on that URL shows the current price and network. Only do this if your human has given you a wallet to spend from.

## Who is hitting my site? (Overwing Atlas)

Atlas is Overwing's open data on AI agents: who they are, where they go, what they spend. The part you will use most is the lookup: paste a User-Agent string and get what it claims to be and whether the claim can be trusted.

```bash
{baseDir}/scripts/overwing.sh who "Mozilla/5.0 (compatible; ClaudeBot/1.0; +claudebot@anthropic.com)"
```

Returns `identified`, `claims` (agent, operator, purpose_class, verification), a `trust_note`, and the other matches. Read `verification` before acting: `Web Bot Auth signature` means the operator signs requests and you can verify the Signature-Agent header against its key directory; `User-agent string only (spoofable)` means anyone can send that string; `Unattributable / spoofed` means the operator does not identify itself at all. Free keys get 100 lookups a day; Atlas Pro raises it to 10,000. Wallet-holding agents can pay $0.001 per lookup at `GET https://overwing.ai/api/x402/atlas/lookup?user_agent=...` with no account.

Search the registry or read the public summary:

```bash
{baseDir}/scripts/overwing.sh agents --purpose browser --limit 10
{baseDir}/scripts/overwing.sh atlas
```

Full datasets, the field scans, and the research report are at https://overwing.ai/atlas.

## Custom rules

Your human can define rules in plain language (yes/no questions, classifications, or scored scales) at https://overwing.ai/dashboard/rule-sets or via `POST /api/v1/rule-sets`. Each rule carries an `action` (`block`, `redact`, or `review`) and may reference `context.*` fields in its wording. Then pass the slug with `--rule-set`. `GET https://overwing.ai/api/v1/rule-sets/outbound-message` is a complete context-aware example to copy from.

## More

- Full guide for agents: https://overwing.ai/llms.txt
- API reference: https://overwing.ai/docs
- Prefer MCP? `npx -y overwing-mcp` exposes the same calls as tools.
- Node or Python SDKs: `npm install overwing`, `pip install overwing`.

Verdicts are signals from a calibrated model, not guarantees. When the stakes are high and the recommended action is not `allow`, involve your human.
