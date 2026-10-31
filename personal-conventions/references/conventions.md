#  Convention Reference

## Preferred operation shape

Write functions so the reader resolves failure conditions before reaching the main action:

```text
assign/extract inputs

validate presence and shape
return/raise typed failure when invalid

validate ownership, state, and domain rules
return/raise typed failure when invalid

perform the operation

map and return success
```

Prefer:

```text
if invalid:
    return failure

if forbidden:
    return forbidden

result = process()
return success(result)
```

Avoid unnecessary nesting:

```text
if valid:
    if allowed:
        return success(process())
    else:
        return forbidden
else:
    return failure
```

A default result assigned near the top can be useful when several independent checks refine it, but do not use a mutable default merely to avoid a direct early return.

## Defensive-programming checklist

Before side effects, check the relevant subset of:

- required values and types;
- bounds, formats, and allowed enum values;
- cross-field relationships;
- authentication, authorization, and tenant ownership;
- current state and allowed state transition;
- idempotency and duplicate-operation rules;
- referenced records and configuration;
- integration prerequisites;
- monetary amount, currency, and account invariants;
- whether a failure requires compensation.

Handle realistic failure paths, but do not bury the main flow under speculative checks that cannot occur given established type or framework guarantees.

## Feature-local layout

Use ecosystem naming while preserving this ownership model:

```text
feature/
  controller-or-handler
  params/
    request/
    response/
  service-or-use-case

integrations/
  provider-name/
    client
    implementation
    params/
      request/
      response/
    mapper
    errors

models/
repositories/
config/
```

An integration should be understandable without searching a global DTO directory. Promote a type to a shared package only when it represents a genuinely shared domain or API contract, not merely because several files use it.

## Domain boundaries and orchestration

Organize cohesive business capabilities as implementation domains. For example:

```text
domains/
  transfer/
    models
    rules
    repository contract
    transfer service

  limits/
    models
    policies
    repository contract
    check / reserve / consume / release operations

application/
  initiate-transfer use case
```

The application flow coordinates domains without absorbing their rules:

```text
validate transfer request
  → limits.check/reserve(...)
  → transfer.debit(...)
  → verify debit success
  → transfer.credit(...)
  → limits.consume(...)
  → return result

on relevant failure
  → transfer.reversal/refund(...)
  → limits.release/reverse(...)
```

The exact sequence depends on business requirements, but ownership does not change:

- transfer owns debit, credit, transfer status, and transfer compensation;
- limits owns limit policy, counters, reservations, consumption, and release/reversal;
- the application orchestrator owns sequencing across those contracts;
- neither domain reaches into the other's database tables, repositories, or internal models.

Use domain-specific request/result types at the boundary. Translate external and transport parameters before calling the domain. If domains must react without direct orchestration, publish explicit domain events and define delivery, idempotency, ordering, and failure behavior.

Indicators that something deserves its own domain/module include independent vocabulary, business policies, lifecycle/state machine, persistence ownership, security rules, team ownership, or frequency of change. A helper function or formatting concern does not become a domain merely because it is reusable.

## Interface and registry pattern

```text
Capability contract
  ├─ Implementation A ─┐
  ├─ Implementation B ─┼─ registry/factory keyed by closed identifier
  └─ Implementation C ─┘                    ↓
                              tenant/config selection
```

Use the native abstraction:

- Java: interface + enum + injected implementations/factory map.
- Python: `Protocol` or ABC + `Enum` + dependency-injected registry dictionary.
- TypeScript: interface/type contract + string enum or literal union + typed registry/DI token.
- Rust: trait + enum + `HashMap`/match-based factory; use `Box<dyn Trait>` when runtime polymorphism is required and generics when selection is static.

Keep registries focused: a processor registry chooses processors; a storage registry chooses storage implementations. Do not create a universal factory.

## Result and absence types

- Java: `Optional<T>` for absence; Vavr `Either<L, R>` or an explicit result type for expected domain failures. `@SneakyThrows` is acceptable when a checked exception should abort and local handling adds no value.
- Python: return a clear result model for expected domain failures; use `None` only for genuine optionality and exceptions for exceptional failures. Use type hints throughout public boundaries.
- TypeScript: prefer discriminated unions such as `{ ok: true, data } | { ok: false, error }`; use `T | undefined`/`null` deliberately for absence.
- Rust: use `Option<T>` for absence and `Result<T, E>` for fallible operations; propagate unexpected/local failures with `?` and use domain error enums.

Expected failure values should be difficult for callers to ignore. Avoid sentinel strings, magic numbers, or ambiguous nulls.

## HTTP contracts

Use a consistent shape such as:

```json
{
  "data": {},
  "message": "Operation completed",
  "traceId": "...",
  "meta": {}
}
```

On failure, use the appropriate HTTP status and a stable error structure. `data` may be `null` or omitted according to the project's chosen envelope, but keep that choice consistent.

Validate transport parameters with ecosystem tools:

- Java/Spring: Jakarta Bean Validation plus `@Valid`/`@Validated`.
- Python: Pydantic/dataclass validation or framework-native schemas; keep domain validation separate.
- TypeScript: runtime schema validation such as Zod or the project's established validator; static types alone do not validate network input.
- Rust: typed extractors plus `serde` and explicit validation/domain constructors.

## Persistence and queries

Keep query semantics in the repository/data-access layer. Prefer simple derived/query-builder methods only while intent remains obvious. Once a query has roughly four parameters, several predicates, joins, or an unreadable generated name, write the query explicitly with named/bound parameters or use the ecosystem's typed query/specification facility.

Never concatenate untrusted values into queries. Return domain models or focused projections so callers do not reconstruct joins and filters.

### Stored procedures

Do not reach for a stored procedure first. Consider one when:

- a report aggregates many fields or large datasets and executing near the data materially improves performance;
- a database-local workflow requires several tightly coupled mutations to succeed or fail atomically;
- reducing application/database round trips has demonstrated value; or
- the database already owns the relevant transactional invariant.

Keep the procedure versioned and reviewed like application code. Use bound parameters, define its transaction and error behavior, keep business ownership clear, and cover it with integration tests. Do not move ordinary application logic into the database solely to shorten service code.

## Concurrency and sequencing

Start by drawing the dependency relationship:

```text
Independent prerequisites
  name lookup ───┐
                 ├─ await both → validate combined result → process transfer
  balance lookup ┘

Dependent financial steps
  debit → verify success → credit → verify result → compensate if required
```

Parallelize only the first shape. Keep the second sequential because the later side effect depends on the earlier result.

Across ecosystems:

- Java: `CompletableFuture`, structured concurrency where available, or the project's async abstraction; use executors deliberately.
- Python: `asyncio.gather`/task groups for independent I/O; avoid blocking calls on the event loop.
- TypeScript: `Promise.all` for independent promises and `Promise.allSettled` only when partial results have defined semantics.
- Rust: `join!`, `try_join!`, or task sets for independent async work; propagate cancellation and errors deliberately.

Define timeout, cancellation, retry, ordering, and partial-failure behavior before introducing concurrency. Do not parallelize financial side effects merely to reduce latency.

## Performance decision hierarchy

Use this order of preference:

1. correct and defensive;
2. straightforward to read;
3. easy to maintain and modify;
4. efficient enough for the known workload; and
5. more complex optimization only when justified.

Before choosing a less-readable optimization, record or establish:

- the observed bottleneck, benchmark, query plan, production symptom, or credible scale constraint;
- the simpler implementation considered;
- the expected improvement and important resource tradeoffs;
- the new ordering, concurrency, memory, or correctness assumptions;
- how the behavior will be measured and tested; and
- whether Beodun approved the maintainability tradeoff when it is substantial.

Keep the benchmark or profiling method reproducible when possible. If the need disappears, prefer simplifying the implementation rather than preserving complexity because it was once faster.

## Collections and complexity

- Use a map/dictionary when repeatedly finding values by key.
- Use a set when repeatedly checking membership or removing duplicates.
- Avoid nested scans when one indexed pass can construct a lookup structure.
- Prefer lazy streams/iterators for large pipelines when materializing intermediate collections is unnecessary.
- Avoid parallel streams or equivalent parallel collection processing for small workloads, blocking I/O, shared mutable state, or order-sensitive side effects.
- Preserve readability: a clear loop with explicit early failure is better than a dense pipeline.

## Informative comments and notes

Comments should preserve knowledge that cannot be made obvious through naming, types, or structure. Good subjects include:

- why a performance optimization is necessary;
- why operations must remain sequential or may safely run concurrently;
- state-machine behavior and prohibited transitions;
- compensation/reversal/refund rules;
- external-provider quirks or malformed-response handling;
- security or tenant-isolation invariants;
- idempotency, ordering, retry, and duplicate-delivery assumptions; and
- a modification that looks harmless but violates an important invariant.

Prefer a short note immediately above the affected code:

```text
// PENDING means the provider has accepted the transfer but has not finalized it.
// Do not reverse here; requery owns resolution and may still report SUCCESS.
```

For performance-specific code:

```text
// Build a keyed lookup once because this path processes up to N records and was
// measured as the report bottleneck. Preserve O(n) lookup behavior when editing.
```

Avoid comments that merely restate syntax, commented-out code, unexplained warnings, or stale historical narratives. For a large design decision, keep the local warning brief and link to a maintained decision record, benchmark, issue, or test.

## Financial records and projections

Treat these as different models:

```text
Financial journal (append-oriented)
  debit → credit → reversal/refund
  each entry has its own identifier and links to related entries

Customer summary (mutable projection)
  one row/document representing the latest understandable status
```

Persist sufficient correlation, provider references, amount/currency, timestamps, status, and non-sensitive failure information to reconstruct what happened. Make compensation idempotent and verify it happens at most once unless the design explicitly supports safe retries.

### Money

A monetary value is an amount plus a currency. Keep those inseparable in domain code. The canonical domain representation uses major currency units: `10.50 NGN`, not `1050` kobo.

- Java: use a `Money` value object backed by `BigDecimal` major units; define scale and rounding explicitly.
- Python: use `Decimal` inside a validated money model; never use `float`.
- TypeScript: use a money type backed by an established decimal library and store major units; JavaScript `number` is not safe for general financial arithmetic.
- Rust: use a money newtype backed by an exact decimal crate in major units, paired with a currency enum/code.

Validate currency compatibility before addition/subtraction, define currency conversion as a separate operation with an explicit rate and timestamp, and define rounding at the boundary where it is required. Convert major units to integer minor units only in a dedicated integration mapper when an external contract requires it, and convert back immediately at ingress. Serialization and persistence should use documented decimal major units unless an existing schema forces another representation.

## Logging

### Request context

Create the context once at the trusted ingress boundary. A representative shape is:

```text
RequestContext
  traceId
  tenantId
  callerId / principal
  callerIp
  source / channel
  userAgent or client identity when useful
  requestId / correlationId when distinct from traceId
  startedAt
```

Keep it immutable and pass it explicitly or through the ecosystem's safe request-local context mechanism. Do not place mutable request data in process-global/thread-global state that can leak between requests. For caller IP, honor forwarded headers only from configured trusted proxies.

Propagate standard tracing headers, preferably W3C `traceparent`/`tracestate`, and approved tenant/source headers to downstream services. Do not accept an untrusted tenant header as authorization; derive or verify tenant identity against the authenticated principal. Ensure async tasks, executor work, queues, and event messages preserve the relevant context.

Language mappings:

- Java: immutable record/value object; servlet filter/interceptor plus MDC and OpenTelemetry context; use context-aware executors for async work.
- Python: immutable dataclass/Pydantic model; middleware plus `contextvars`; propagate OpenTelemetry context through async tasks.
- TypeScript: readonly context type; middleware/interceptor plus `AsyncLocalStorage`; inject tracing headers through the HTTP client wrapper.
- Rust: immutable context struct; framework middleware/extensions and tracing spans; instrument spawned futures explicitly.

### Searchable operational logs

For a multi-tenant operation, structure logs conceptually as:

```text
<tenant> - <operation/event> [traceId]=... [callerId]=... [reference]=... [status]=...
```

The tenant comes first. Use stable field names and event names so logs can be grepped or queried consistently. Include the identifiers needed to follow the operation across its lifecycle. Use structured/parameterized logging rather than string concatenation.

Use levels deliberately:

- `INFO`: operation lifecycle and meaningful business transitions.
- `WARN`: degraded/recoverable conditions requiring attention.
- `ERROR`: failed operations or broken invariants, with the exception and complete stack/cause chain.
- `DEBUG`: detailed decisions, sanitized integration request/response summaries, and handled exceptions useful during investigation.
- `TRACE`: highly verbose step-level or sanitized wire diagnostics enabled temporarily.

Do not log only a human sentence when structured fields can make the event searchable. Avoid changing field names between initiation, completion, and failure events.

### Downstream response diagnostics

Capture the response body once as bytes/text before parsing, then:

1. log status, content type, content length, latency, downstream name, and trace ID;
2. sanitize known secret/PII fields and sensitive headers;
3. truncate or hash oversized/binary content according to configured limits;
4. emit the sanitized raw body at `DEBUG` or `TRACE`; and
5. parse the same captured body and preserve the parsing exception with its stack trace.

This keeps blank bodies, HTML proxy errors, malformed JSON, and unexpected schemas visible without leaking tokens. Never rely on a low log level as the protection for secrets: debug logs are still persisted and accessible.

### Audit trail

Keep business audit events distinct from verbose diagnostics. Record actor, tenant, action, target, timestamp, outcome, trace ID, and relevant before/after facts without secrets. Prefer append-only, access-controlled audit storage with an explicit retention policy for sensitive or regulated actions.

### Exceptions

Do not swallow exceptions silently. When translating an exception into a domain result, returning a fallback, or intentionally continuing:

- preserve or attach the original cause;
- log the exception object so its stack trace is retained;
- add tenant, trace, operation, and relevant entity identifiers; and
- choose `DEBUG` only for genuinely expected/non-actionable failures, otherwise use `WARN` or `ERROR`.

Avoid logging the same exception at every layer. Log it where the layer can add useful context or where it is finally handled; let it propagate otherwise.

## Testing

Group related scenarios using the ecosystem's natural mechanism:

- Java: JUnit `@Nested` classes, AssertJ, Mockito.
- Python: test classes/modules, pytest parametrization, fixtures, and mocks/fakes.
- TypeScript: nested `describe` blocks, table tests, and spies/mocks.
- Rust: nested test modules and table-like case iteration.

For each behavior, test the happy path and each meaningful guard clause. Verify that invalid input prevents downstream calls, successful input triggers the expected collaborator, and failure/compensation paths persist and log the intended state.
