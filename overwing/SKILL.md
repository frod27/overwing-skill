---
name: overwing
description: Check any text for safety, personal data, self-harm, sexual content and severity before you send it, act on it, or show it to a person. One API call returns pass / fail / review per rule with calibrated confidence in under 500 ms. Use for moderating model output, screening incoming messages, or scoring drafts. Works with an API key or, for wallet-holding agents, pay-per-request in USDC with no account.
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

Overwing scores text and returns a typed verdict. Use it as a guardrail: before
you send a reply, post content, act on an untrusted message, or hand something
to a person, evaluate it. `fail` means block or rewrite. `review` means a rule
was unsure: ask your human or take the cautious path. `pass` means go ahead.

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
{ "id": "eval_…", "verdict": "fail", "aggregate_score": 0.82, "confidence": 0.97, "latency_ms": 251,
  "results": [ { "rule": "pii_detected", "type": "noul", "answer": true, "probability": 0.99, "confidence": 0.98, "verdict": "fail" }, … ] }
```

How to act on it:

| verdict | meaning | what to do |
| --- | --- | --- |
| `fail` | a rule's fail condition matched | do not send; rewrite without the flagged content, or tell your human what was flagged and why |
| `review` | no rule failed, but one was unsure (confidence under its threshold) | ask your human, or take the safer option |
| `pass` | nothing tripped | proceed |

`results[].rule` names the rule; the prebuilt set has `toxicity`, `pii_detected`, `self_harm`, `sexual_content`, `severity`. `confidence` is 0 to 1. Read the rule list before deciding: a `fail` on `pii_detected` with a `pass` on everything else means "remove the personal data", not "the message is hostile".

Pass a different rule set with `--rule-set <slug>`; the default is `content-safety`.

## Evaluate many texts at once

Up to 50 per call, one line of JSON per item on stdin:

```bash
printf '%s\n' '{"id":"a","input":"first"}' '{"id":"b","input":"second"}' | {baseDir}/scripts/overwing.sh batch
```

Returns a summary plus per-item verdicts. Each item counts as one check.

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

## Custom rules

Your human can define rules in plain language (yes/no questions, classifications, or scored scales) at https://overwing.ai/dashboard/rule-sets or via `POST /api/v1/rule-sets`. Then pass the slug with `--rule-set`. `GET https://overwing.ai/api/v1/rule-sets/content-safety` is a complete example to copy from.

## More

- Full guide for agents: https://overwing.ai/llms.txt
- API reference: https://overwing.ai/docs
- Prefer MCP? `npx -y overwing-mcp` exposes the same calls as tools.
- Node or Python SDKs: `npm install overwing`, `pip install overwing`.

Verdicts are signals from a calibrated model, not guarantees. When the stakes are high and the verdict is not a clear `pass`, involve your human.
