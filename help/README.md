# Catch 5 support server

`api/support.ts` is the optional native-app route. It is separate from the existing browser help chat. `support-core.mjs` validates requests and calls the OpenAI Responses API using server-side credentials. No deployment or live API test has been performed.

## Local app behavior

Tap Support beside the rules book. Computers pause while the sheet is open. Up to three phase-aware starting questions use the normal online chat path when enabled; without a server they return concise, labelled offline help. Starters appear only before the conversation begins. Advice uses only the requesting seat's own cards and public facts. Finished-score help leads with settled scores, contract result and arithmetic; its context also includes public category winners and Game values. Neither names from settings nor private opponent cards are sent.

Chat is ephemeral: closing it, a seat/curtain transition, or any game revision ends the session. It is never put in the game save. Local free text chooses one of the three local explanations; it is labelled local help rather than an AI answer.

## Secure setup before enabling online questions

1. Set up a dedicated OpenAI API project. Review its credits and spending controls, disable automatic recharge unless separately authorized, and set an affordable credit amount/alerts before enabling live calls. Project budgets/alerts and this route's warm throttle are not guaranteed durable spending caps. The API incurs charges; configuring it does not authorize spending in this task.
2. Supply `OPENAI_API_KEY` (or the existing sensitive Vercel environment alias `OpenAi`, with exactly that capitalization) and a long random `SUPPORT_CODE` using the host's server environment/secret controls, never source control, the mobile bundle, logs, query strings, or the support chat. A nonblank `OPENAI_API_KEY` takes precedence; otherwise the server uses nonblank `OpenAi`. If both key names are absent/blank, or `SUPPORT_CODE` is absent/blank, the route returns 503 before contacting OpenAI. This alias is resolved only on the server; no secret needs to be read, renamed or copied into the app. Optional `SUPPORT_MODEL` defaults to `gpt-6-luna`; model overrides are server-only.
3. Host `help/` with a Node serverless runtime supporting `api/support.ts` (for example Vercel). The route uses built-in fetch and no added dependencies. Deploy only with separate authorization. Keep function/request-body logging disabled; do not log cards, questions, access codes or Authorization headers. Infrastructure metadata logging is controlled by the host and must be reviewed there.
4. On the app's Support sheet choose the settings gear. Enter the HTTPS `/api/support` URL and support access code, turn on Online answers and choose Apply. The app persists only endpoint/code and the online-mode preference in its settings; the code is a shared access credential stored in app preferences, not an OpenAI key. Use a private, revocable code and rotate it in server and app together. Online support is off by default until explicitly enabled; that mode choice persists across sheet presentations. Opening the sheet sends no request: an online question requires Send or an explicit starter tap. The disclosure explains which facts leave the device.

Endpoints with credentials, query strings, fragments or HTTP are refused. Every HTTP redirect is refused, including to another HTTPS host. No cookies, disk URL cache or chat persistence is used by the client. The client makes one request at a time, cancels on dismissal, discards late replies, and never retries automatically. Failed questions stay visible with explicit Try again and Offline help actions. The ephemeral screen transcript can continue beyond five questions; only the bounded online history is sent. Local help remains available after network/configuration/auth/upstream errors.

## Contract and bounds

POST JSON with `x-support-code` header:

```json
{"messages":[{"role":"user","text":"Explain the score"}],"context":{"seat":0,"phase":"bidding","cards":[],"nextSeat":0,"dealer":3,"scores":[0,0],"calls":[],"trick":[],"completedTricks":[],"discardCounts":[0,0,0,0],"legalOptions":[]}}
```

Success: `{ "reply": "..." }`. Errors: short non-secret `{ "error": "..." }` with 400/401/405/413/429/502/503. There is no public unauthenticated paid fallback.

Each request contains at most the last four completed online pairs plus the new question (9 alternating messages starting/ending user), 2,000 UTF-16 code units each (matching JavaScript string length); context has an explicit field allowlist, bounded strings and arrays (six own cards, four current plays, six completed tricks); total body is at most 48 KiB. Extra fields such as opponent hands or system instructions are rejected. Context and messages remain untrusted data in server instructions; only canonical house rules are authoritative. Client-provided engine facts are grounded for a normal app client, not cryptographically attested.

The server posts once to `https://api.openai.com/v1/responses` with `store:false`, `max_output_tokens:240`, no tools, and a 15-second abort timeout. It reads all `output[].content[]` items of type `output_text`; refusal, incomplete, empty, malformed, non-200 and transport errors produce a generic fallback error. No paid retry occurs. `store:false` does not promise zero provider retention; review your OpenAI project's data controls.

A three-second throttle is shared only within each warm server instance. Instances restart and run concurrently; it is accidental-repeat protection, not an account-level rate limiter, abuse defense or spending cap. Before wider distribution use host-level access controls and durable quota enforcement; this feature does not add accounts or billing systems.

Default online replies target 20–60 words and 1–3 direct sentences with essential exceptions; these are product targets, not proven UX thresholds. Reasoning stays none and there are no extra summary or streaming requests. Longer replies have a bounded whole-word/sentence preview and More/less expands the same answer locally. Only submitted questions trigger scroll positioning; replies and expansion never force a jump to their end. Connection settings live in a secondary sheet and the composer uses the keyboard-safe bottom inset. Actual phone and large Dynamic Type acceptance still require observation.

House rules are embedded from `../docs/catch-five-rules.md` in the server instructions. Keep this copy current when changing those rules; a test checks exact parity.

## Verification without credentials or paid requests

From the repository root, sequentially:

```sh
node --test help/support.test.mjs
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer python3 scripts/build-simulator.py
```

Tests use controlled HTTP transport. They cover missing config/auth, malicious/bounded data, upstream request/response/error handling, opponent-card mutation privacy, legal/advice/scoring, pass-and-play curtain, local help, cancellation and duplicate sends. Simulator SDK build can run without an installed runtime; actual display and Dynamic Type inspection requires an installed compatible iOS runtime. No phone installation is part of this change.

Official references: https://developers.openai.com/api/docs/guides/text ; https://developers.openai.com/api/docs/models/gpt-6-luna ; https://developers.openai.com/api/docs/guides/api-keys .
