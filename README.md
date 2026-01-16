# Saumon Druid

**RAG-based Natural Language Query System for Parliamentary Data**

Saumon Druid is a Rails-based application that ingests large volumes of parliamentary data and enables natural-language querying through a hybrid search and LLM-assisted workflow. The project focuses on **data pipelines, search relevance, and observability**, rather than UI polish.

> [!WARNING]
> **Public Mirror** — This is a read-only snapshot of a private repository, shared for portfolio purposes. Some files are intentionally omitted. The project is under active development.

---

## 🎯 Problem Statement

Political information from the French Parliament is **publicly available but difficult to access and understand**.

Citizens, journalists, and political actors who want to follow parliamentary activity or understand political positions face several challenges:

- Parliamentary data is dense, verbose, and often written in **technical or institutional language**
- Tracking **recent updates** (new debates, amendments, votes) on a specific topic is time-consuming
- Understanding **context and evolution** ("what changed?", "what is the impact?") requires digging through long documents
- Raw parliamentary records are not designed for **searchability or synthesis**

As a result, even engaged users struggle to:

- stay informed in a **clear and comprehensible way**
- quickly identify relevant parliamentary activity
- understand how debates and positions evolve over time

**Saumon Druid aims to bridge this gap** by making French parliamentary data searchable, contextualized, and easier to explore.

---

## 🧠 Core Features

| Area | What it does |
|------|--------------|
| **Data Pipeline** | Batch ingestion from external API with upsert logic and relationship mapping |
| **Hybrid Search** | Vector (pgvector) + full-text (tsvector) + trigram (pg_trgm) in PostgreSQL |
| **Agent Orchestration** | Multi-stage LLM pipeline: safety → rewrite → plan → execute → compose |
| **Query Execution** | Dependency-aware parallel execution with timeout protection |
| **Observability** | Structured events on every step, stored in TimescaleDB for analysis |

---

## 🏗 Architecture Overview

```
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│  Data Ingestion │  →   │  Hybrid Search  │  →   │  Agent Pipeline │
│  (SaumonNet API)│      │  (pgvector +FTS)│      │  (LLM reasoning)│
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

1. **Ingest** — Fetch parliamentary data, normalize, and embed stakeholder profiles
2. **Search** — Combine vector similarity + full-text + trigram for hybrid retrieval
3. **Plan** — LLM generates a structured, dependency-aware query plan
4. **Execute** — Run query steps in parallel, respecting dependencies
5. **Compose** — LLM synthesizes results into a French-language answer

**Tech:** Rails 8 • PostgreSQL (pgvector, TimescaleDB) • Sidekiq • Docker

---

## 🔍 Observability & Debugging

RAG systems often feel like a black box. This project takes the opposite approach:

- **Full event trail** — Every stage (ingestion, planning, execution, composition) emits structured events
- **Correlation IDs** — Session, request, job, and conversation IDs propagate through all layers
- **TimescaleDB storage** — Events are stored as time-series data for efficient querying
- **Debug-friendly** — Trace why a query failed, which steps timed out, or what the LLM received

---

## 🧪 What This Project Demonstrates

- Designing **data-intensive Rails systems**
- Applying **modern AI patterns** (RAG, embeddings) pragmatically
- Using PostgreSQL beyond traditional relational use cases
- Building **observable, debuggable pipelines**
- Thinking in terms of **product impact**, not just model accuracy

---

## 📌 Non-goals

- Production-ready UI
- Turnkey deployment
- Generic RAG framework

This project is intentionally focused on **engineering decisions and trade-offs**.

---

## 📄 License

MIT (see LICENSE file)

---

## 👤 Author

Vincent Pelle — Senior Software Engineer (Ruby / Rails)
