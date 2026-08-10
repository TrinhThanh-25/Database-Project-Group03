# Group 03 Agent Entry Point

The assignment refers to `AGENT.md`; the repository's canonical project instruction file is `AGENTS.md`. Read and follow `AGENTS.md` in full. It defines both the Phase 1 baseline pipeline and the Phase 2 extension pipeline, file routing, traceability, assumptions/open-question handling, and logging requirements.

Phase 2 starts from `req/phase-2-business-requirement.md` and produces artifacts `outputs/08-*` through `outputs/16-*` sequentially. Do not bypass an unfinished upstream artifact.

Phase 2 agent improvements: the pipeline now has separate owners for requirement changes, migration, concurrency, testing, scale data, analytics, and tuning. Its checks are requirement-proportional: migration remains additive and data-preserving without requiring production-scale schema fingerprinting, and the generator may use a fixed deterministic 100,000-row classroom configuration.
