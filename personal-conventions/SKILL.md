---
name: beodun-personal-conventions
description: "Design, implement, optimize, refactor, or review simple and defensive services according to  personal conventions. Applies across Python, TypeScript, Rust, Java, and other languages: readability-first maintainability, validation-first flows, explicit performance decisions, dependency-aware concurrency, early returns, domain separation, request-context propagation, informative invariant comments, searchable diagnostics, exact monetary types, and auditable records."
---

#  Personal Conventions

Apply these principles across languages and frameworks. Adapt the syntax and ecosystem tools, but preserve the architecture, readable control flow, defensive validation, and traceability.

## Write validation-first flows

- Arrange operations as: assign/extract inputs, validate every required precondition, process the successful path, then map and return the result.
- Handle known failure states as soon as they become identifiable. Prefer guard clauses and early returns so the remaining code reads as the successful path.
- Avoid `else` when an earlier branch can return, throw, continue, or otherwise terminate. An `else` is acceptable when it represents a genuinely symmetric choice and improves clarity.
- Use defensive programming: validate external input, absence, ranges, formats, cross-field constraints, state transitions, authorization, tenant ownership, and integration assumptions before performing side effects.
- Do not use language assertions for recoverable input or business failures. Use validation results, typed errors, exceptions, or result types appropriate to the language. Reserve assertions for internal invariants that indicate programmer defects.
- Separate logical phases with one blank line. Extract a named function when a section changes domain or responsibility.

## Structure by responsibility and feature

- Keep controllers/handlers thin: validate transport input, invoke the relevant application component, and map the protocol response.
- Keep domain and persistence models in a dedicated `models` area. Do not mix them with HTTP or integration parameter types.
- Avoid a global DTO/VO dumping ground. Put endpoint parameter types in focused `params/request` and `params/response` areas near their feature.
- Colocate each external integration's client, request/response parameters, mappings, errors, and implementation inside that integration's feature folder.
- Keep distinct business-component families—processors, payment rails, storage providers, notification providers—outside a generic services bucket when they form an architectural concept of their own.

## Separate implementation domains

- Treat each cohesive business capability as its own domain/module with clear ownership of its rules, models, state transitions, persistence, and public contract.
- Do not embed one domain's implementation inside another domain's workflow. A transfer flow may ask the limits domain to check, reserve, consume, release, or reverse a limit; it must not calculate or mutate limit state itself.
- Put cross-domain sequencing in a thin application use case/orchestrator. Domains communicate through narrow interfaces and domain-level commands/results, not each other's repositories or internal models.
- Keep compensation owned by the domain whose state is being compensated. The orchestrator decides when compensation is required; the owning domain performs it and enforces idempotency.
- Split domains when a capability has independent rules, lifecycle, data ownership, vocabulary, or reasons to change. Do not split merely to create more folders.

## Abstract interchangeable capabilities

- Define a stable interface/trait/protocol for a capability with multiple implementations.
- Give each implementation a closed identifier, preferably an enum or equivalent algebraic type.
- Use a factory/registry keyed by that identifier to select implementations. Keep separate capability families in separate registries.
- Prefer tenant/configuration-driven selection over controller conditionals or scattered `if`/`switch` statements.
- Centralize mapping from external/provider states into domain states.

## Keep APIs and operations explicit

- Expose one canonical endpoint per operation. Add aliases only as deliberate, temporary migration compatibility.
- Use normal HTTP status codes and a consistent response envelope whose payload is under `data`, with message, error, trace, pagination, or metadata fields as needed.
- Validate request parameters at the boundary and place cross-field/business validation in a named validator or domain function.
- Keep OpenAPI metadata with the implementation when applicable, but disable documentation endpoints by default and enable them only through explicit environment configuration.
- Prefer enums/closed types for bounded states, operation types, implementation identifiers, response categories, and transitions rather than scattered strings.

## Optimize deliberately

- Optimize first for straightforward readability and long-term maintainability. Prefer code that can be understood, tested, and changed safely over a faster but obscure implementation.
- Treat performance complexity as an explicit engineering decision, not a default. Establish the bottleneck or credible scale constraint, compare the readable design, and document the tradeoff.
- If an optimization materially reduces readability or maintainability, do not introduce it silently. Ask for  approval unless the requirement or existing design already authorizes that tradeoff.
- Identify independent I/O operations and run them concurrently when doing so preserves correctness and produces a meaningful latency improvement.
- Keep dependent operations sequential. Never parallelize steps whose correctness requires the preceding result—for example, confirm a debit succeeds before initiating its credit.
- Make concurrency bounded, observable, cancellable where supported, and explicit about timeout and partial-failure behavior. Do not launch unbounded work merely because async syntax is available.
- Choose collections by access pattern. Use hash maps/dictionaries for keyed lookup and hash sets for membership/deduplication instead of repeatedly scanning lists.
- Use streams, iterators, comprehensions, or equivalent collection pipelines when they remain clear. Prefer a simple loop when it communicates state, failure, or side effects better.
- Consider algorithmic complexity and data volume before micro-optimizing. Measure important paths when practical, and retain benchmarks or evidence for non-obvious optimizations.
- Keep computation near the database only when the database is the right execution boundary. Stored procedures are an option for large reports or strongly transactional database workflows, not the default for ordinary domain logic.

## Preserve important knowledge in code

- Prefer expressive names and clear structure over comments that narrate what each line does.
- Add a focused comment or note where a maintainer must understand a non-obvious invariant, state behavior, performance tradeoff, edge case, external-system quirk, compensation rule, or dangerous modification point.
- Explain why the code is shaped this way, what must remain true, and what can break—not merely what the syntax does.
- Comment performance-oriented code with the bottleneck/constraint, why the simpler approach was insufficient, and any ordering, complexity, or memory assumptions that must be preserved.
- Put state-machine knowledge beside the relevant branch—for example, that a `PENDING` state intentionally has not triggered reversal and must be resolved by requery before compensation.
- Keep comments concise, current, and test-backed where possible. Update or remove them when the invariant or implementation changes.

## Preserve traceability and financial history

- Build an immutable request context at ingress containing the trace ID, tenant, authenticated caller/principal, source/channel information, caller IP, and other stable correlation identifiers relevant to the service.
- Propagate the request context through internal async work and propagate the trace ID plus approved correlation fields to every downstream call. Preserve an accepted upstream trace ID or generate one when absent.
- In multi-tenant systems, put the tenant identifier first in every operational log, followed by trace ID and the operation's non-sensitive identifiers.
- Log initiation, important transitions, integration requests/results, failures, compensation, and completion with stable, structured, grep-friendly field names.
- Record business-significant actions in an audit trail distinct from diagnostic logs. The audit should identify who did what, for which tenant/entity, when, and with what outcome.
- Log downstream HTTP status and a sanitized, size-bounded raw response at debug/trace level before parsing so malformed, blank, proxy-generated, or unexpected responses remain diagnosable.
- Preserve exception type, message, cause chain, and stack trace. If an exception is intentionally handled or ignored, log it at a level appropriate to its operational importance—at least debug when it would help investigation.
- For financial/accounting operations, append distinct linked debit, credit, reversal, and refund entries. Do not erase financial history by turning one record into another meaning.
- Mutable updates are appropriate for customer-facing summaries/projections that intentionally represent only the latest status. Keep them distinct from the append-oriented financial journal.
- Represent money in major currency units by default—for example, `10.50 NGN` rather than `1050` kobo—using an exact monetary abstraction that always includes currency. Never use binary floating point for financial arithmetic. Convert to minor units only at an external boundary that explicitly requires them; if the language lacks a safe native representation, introduce a validated `Money` type.
- Never persist plaintext credentials, access/refresh tokens, session secrets, cryptographic material, or prohibited personal data in logs—even at debug/trace. Redact sensitive fields while retaining response shape, status, headers safe to expose, length, and enough sanitized content to diagnose the failure.

## Use expressive language features

- Prefer the latest stable language version supported by the project and its dependencies.
- Use option/result/either types where absence or domain failure is expected and the caller should handle it explicitly.
- Let unexpected failures bail out when local handling adds no value; catch errors at boundaries that translate them, compensate side effects, add useful context, or restore invariants.
- Prefer constructor/dependency injection over hidden global dependencies.

## Verify behavior

- Group tests by operation or behavior. Cover the successful path, each validation failure, integration failures, state transitions, and compensation paths.
- Mock or stub external boundaries, then verify important calls and important absences of calls—not only returned values.
- For persistence-heavy flows, assert the appended audit entries separately from any updated summary projection.
- Test that request context survives async boundaries, trace information reaches downstream calls, handled exceptions remain diagnosable, and logging redaction prevents secrets from appearing in captured logs.
- Test each domain's rules independently, then test application orchestration as interactions between domain contracts. Verify one domain never bypasses another domain's public contract to mutate its state.
- Add tests for documented invariants, state caveats, and performance-sensitive behavior so future refactoring cannot silently invalidate the explanatory comment.

Read [references/conventions.md](references/conventions.md) for language mappings, request-context and observability guidance, layout examples, concurrency decisions, collection/query guidance, monetary types, response shapes, and control-flow examples.
