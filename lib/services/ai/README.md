# OpenRouter AI Integration

This directory hosts the OpenRouter integration that powers the
**Market Pulse** and **Quick Actions** sections on the KASHF Lite
home screen.

## Architecture

```
lib/services/ai/
├── openrouter_config.dart      # API key / base URL / model from .env
├── openrouter_client.dart      # HTTP client + retries + sanitization
├── openrouter_rate_limiter.dart # Client-side concurrency cap
├── openrouter_audit.dart       # In-memory audit log
├── ai_models.dart              # Strongly-typed UI models
├── ai_prompts.dart             # System + user prompts (en/ar)
├── ai_parser.dart              # JSON -> models
├── ai_home_service.dart        # High-level fetcher + cache
└── home_data_controller.dart   # State controller + auto-refresh
```

The flow is:

1. `HomeScreen` creates a `HomeDataController` in `initState`.
2. The controller calls `bootstrap()` which (a) hydrates from cache
   and (b) kicks off `AiHomeService.refreshAll()`.
3. `AiHomeService` builds the right prompt for the active locale,
   calls `OpenRouterClient.chatCompletionJson`, and parses the
   response via `AiParser`.
4. The parsed model is published through a stream and rendered by
   the home screen.

## Configuration

All secrets live in `.env` at the project root. A template is
shipped as `.env.example`:

```ini
OPENROUTER_API_KEY=sk-or-...
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1       # optional
OPENROUTER_MODEL=openai/gpt-4o-mini                    # optional
OPENROUTER_REFERER=https://kashf-lite.app              # optional
OPENROUTER_APP_TITLE=KASHF Lite                        # optional
```

`OPENROUTER_API_KEY` is the **only** required field. The other
fields have safe defaults.

## Region / Country

The prompts include a `region` field so the model picks locally
relevant brands, currencies, and examples. Defaults to **Kuwait**
(the primary market). Override per-user via
`HomeDataController.setRegion(...)`.

## Sparkline Timeframe

Sparkline points cover the **last 24 hours, one sample per hour**
(24 points). This shorter window makes the line look like a real
intraday chart instead of a near-straight trend. The
[ai_prompts.dart](lib/ai_prompts.dart) module enforces this in
the system prompt and the parser caps any runaway response at
64 points.

## What The Prompts Do NOT Mention

We deliberately do **not** mention the product brand or any
internal app feature in the system prompt. The model has no
prior knowledge of the product, and brand-coloured wording
adds noise to the response. The prompts focus on:

* the user's locale + region
* the domain (brand-investigation: perfume, beauty, fashion,
  electronics, social-media campaigns)
* the exact JSON schema the UI needs
* hard rules (24 hourly points, no monotonic lines, JSON-only)

## Token Usage Policy

AI calls are **manual-only** to keep OpenRouter token usage
under user control:

* No automatic refresh on `HomeScreen` mount.
* No periodic background polling.
* No refresh on app resume or tab switch.

The app bar exposes a gold refresh button (next to the
notification bell). Tapping it calls
`HomeDataController.refreshNow(...)`, which hits the API and
updates the dashboard. While the request is in flight, the
refresh icon shows a spinner and the section headers swap their
"View all" trailing text for a small gold spinner.

Pull-to-refresh is also wired to the same path — it is
user-initiated, so it does not waste tokens on background
events.

The `.env` file is registered as a Flutter asset in `pubspec.yaml`
and is loaded at startup from `main.dart` via `flutter_dotenv`.

## Reliability

| Concern | Mitigation |
|---|---|
| Network timeouts | 25s per request via `OpenRouterConfig.requestTimeout` |
| Transient 5xx / 429 | Up to 3 retries with exponential backoff + jitter |
| Auth failures | No retry — surfaces immediately |
| Rate limiting | Client-side sliding window: 20 req / 60s, max 4 concurrent |
| Invalid prompts | `PromptSanitizer.sanitize()` strips control chars + injection patterns |
| Bad responses | `AiParser` pads missing fields with safe defaults |
| Missing API key | Falls back to demo data so the UI never goes blank |

## Security

* All traffic is HTTPS.
* The API key is read from `.env` and never logged.
* User-provided prompts are sanitized before they leave the device.
* Every API call is recorded in `OpenRouterAuditLog` with status
  code, duration, token usage, and error type. The body of the
  request is **never** logged (it may contain user PII).

## Testing

```bash
flutter test test/ai/
```

Tests cover:

- `ai_parser_test.dart` — schema validation, padding, clamping.
- `openrouter_client_test.dart` — sanitization, request validation,
  JSON unwrap.

Manual smoke test:

1. Drop your `OPENROUTER_API_KEY` into `.env`.
2. `flutter run`.
3. Watch the home screen — Market Pulse and Quick Actions should
   populate with AI-generated content within a few seconds.
4. Pull-to-refresh to force a fresh fetch.
5. Disable the API key and re-run — the UI should still render
   the demo data without crashing.

## Maintenance

* **Prompt tuning**: edit `ai_prompts.dart`. The system prompt
  describes the JSON schema the model must return. Keep the
  schema in sync with `ai_models.dart`.
* **New sections**: add a new prompt + parser + model, then plug
  the new section into `HomeDataController` and `HomeScreen`.
* **Model swap**: change `OPENROUTER_MODEL` in `.env` or default
  in `openrouter_config.dart`.
* **Telemetry**: extend `OpenRouterAuditEntry` with new fields
  and push them to your analytics sink of choice.
