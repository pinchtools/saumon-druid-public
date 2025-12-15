# Saumon Druid

> Agentic RAG system for querying French National Assembly (Assemblée Nationale) open data using natural language

> **Public Mirror** — This is a read-only snapshot of a private repository, shared for portfolio purposes. Some files are intentionally omitted. The project is under active development.

---

## Design Principles

This project builds on top of Saumon-Net, which is responsible for collecting raw data from the Assemblée Nationale open data APIs and preserving its full history.

Saumon-Net provides a reliable, versioned data source. This project focuses on the next step: transforming that raw data into a clean, normalized knowledge base designed for AI agents. The data is structured to make relationships explicit, consistent, and easy to query.

On top of this foundation, an AI-powered question-answering system allows users to explore parliamentary data using natural language. The system retrieves relevant information and generates clear answers, making complex institutional data accessible to non-experts.

The platform is designed with scalability and observability in mind, ensuring that data processing and AI workflows can be monitored, extended, and maintained over time.

## Engineering Highlights

**Data Lineage** — ETL pipeline with transaction safety: all-or-nothing imports with automatic rollback. Each run tracks processed/created/updated/skipped/failed counts. Supports incremental sync via date filtering.

**Hybrid Search** — Combines French full-text search (stemming, stopwords) with trigram fuzzy matching and pgvector semantic embeddings. Weighted scoring adapts to query type.

**LLM Agents** — YAML-configured agents with schema-validated inputs/outputs. Decouples prompt engineering from code.

**Observability** — Single `track_event` entry point for all instrumentation. Events are persisted to TimescaleDB for audit, then asynchronously routed to Sentry (errors) and New Relic (metrics). No scattered `Rails.logger` or direct SDK calls.

## Tech Stack

| Layer | Technology |
|-------|--------|
| Framework | Rails 8.0 |
| Database | PostgreSQL + pgvector + TimescaleDB |
| Background Jobs | Sidekiq |
| Deployment | Docker |
| Monitoring | Sentry + New Relic |


## License

Private - All rights reserved
