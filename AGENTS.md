# AGENTS.md — deer-flow

**Branch**: main  
**Commit**: ab0c10f  
**Generated**: 2026-03-17

## OVERVIEW

DeerFlow 2.0 is a super agent harness built on LangGraph and LangChain. It orchestrates sub-agents, memory, and sandboxes to execute complex multi-step tasks through extensible skills. The architecture splits into publishable harness (packages/harness/deerflow/) and unpublished app (app/). Supports Docker/Kubernetes sandbox modes, MCP servers with OAuth, and 3 messaging channels (Telegram, Slack, Feishu).

## STRUCTURE

```
deer-flow/
├── backend/                         # Python FastAPI + LangGraph
│   ├── packages/harness/deerflow/   # Publishable harness (PyPI candidate)
│   │   ├── sandbox/                 # Sandbox provider abstraction
│   │   │   ├── local/               # Local execution provider
│   │   │   ├── middleware.py        # Sandbox middleware (ThreadData injection)
│   │   │   ├── sandbox_provider.py  # Abstract base class
│   │   │   └── tools.py             # Sandbox tool wrappers
│   │   ├── mcp/                     # MCP client + OAuth
│   │   ├── models/                  # LLM factory (LangChain class loader)
│   │   └── client.py                # Embedded Python client (Gateway-aligned)
│   ├── app/                         # Unpublished application layer
│   │   ├── gateway/                 # FastAPI Gateway (port 8001)
│   │   │   ├── routers/             # REST API endpoints
│   │   │   └── app.py               # Gateway entry point
│   │   └── channels/                # Telegram/Slack/Feishu bridges
│   └── tests/                       # Pytest suite (44 test files)
├── frontend/                        # Next.js 15 + TanStack Query
│   ├── src/
│   │   ├── app/                     # App Router pages
│   │   ├── components/              # React components (ui/, workspace/, ai-elements/)
│   │   ├── core/                    # Business logic (threads, skills, artifacts, memory)
│   │   └── hooks/                   # React hooks (thread lifecycle)
│   └── AGENTS.md                    # Frontend-specific architecture doc
├── skills/public/                   # Built-in skills (research, report, slides, image, video)
├── docker/                          # Dockerfiles (gateway, langgraph, provisioner, nginx)
├── config.yaml                      # Model + sandbox + channel config
├── Makefile                         # dev, docker-start, docker-init, up, down, check, install
└── pyproject.toml                   # uv workspace (backend + harness)
```

## WHERE TO LOOK

| Task | Path | Notes |
|------|------|-------|
| Lead agent middleware chain | backend/packages/harness/deerflow/ | 10 middleware: ThreadData, Uploads, Sandbox, DanglingToolCall, Summarization, TodoList, Title, Memory, ViewImage, SubagentLimit |
| Sandbox provider interface | backend/packages/harness/deerflow/sandbox/sandbox_provider.py | Abstract base: create_sandbox(), execute_bash(), read_file(), write_file() |
| Local sandbox implementation | backend/packages/harness/deerflow/sandbox/local/ | Direct host execution (no container) |
| Docker sandbox detection | backend/tests/test_docker_sandbox_mode_detection.py | Provisioner auto-start logic |
| MCP OAuth flows | backend/packages/harness/deerflow/mcp/oauth.py | client_credentials, refresh_token |
| Gateway API routers | backend/app/gateway/routers/ | uploads, suggestions, skills, artifacts, memory, models, mcp, agents, channels |
| Embedded Python client | backend/packages/harness/deerflow/client.py | In-process Gateway-aligned API (chat, stream, list_models, upload_files) |
| Channel bridges | backend/app/channels/ | telegram.py, slack.py, feishu.py (long-polling/Socket Mode/WebSocket) |
| Frontend thread hooks | frontend/src/hooks/ | LangGraph SDK streaming, thread lifecycle |
| Skill system | skills/public/ | SKILL.md format, progressive loading |
| Memory extraction | backend/packages/harness/deerflow/memory/ | LLM-based extraction, debounced queue, 5-category facts |
| Subagent executor | backend/tests/test_subagent_executor.py | Dual thread pool (3+3 workers), 15-min timeout |
| Model factory | backend/packages/harness/deerflow/models/factory.py | LangChain class loader (langchain_openai:ChatOpenAI) |

## CONVENTIONS

**Python**:
- ruff lint + ruff format (line length 240)
- pytest with asyncio_mode=auto
- Logging: `logging.getLogger(__name__)`, never print()
- Type hints: Python 3.10+ syntax (`str | None`)
- Config: Pydantic Settings with env var expansion (`$OPENAI_API_KEY`)

**TypeScript**:
- ESLint + Prettier
- TanStack Query for server state
- LangGraph SDK 1.5.3 for streaming
- Shadcn UI + MagicUI + React Bits

**Docker**:
- `make docker-start` auto-detects sandbox mode from config.yaml
- Provisioner only starts when `sandbox.use: deerflow.community.aio_sandbox:AioSandboxProvider` with `provisioner_url`
- `make docker-init` pulls sandbox image once

**Config**:
- config.yaml: models, sandbox, channels, skills
- .env: API keys (TAVILY_API_KEY, OPENAI_API_KEY, INFOQUEST_API_KEY, TELEGRAM_BOT_TOKEN, etc.)
- Sandbox modes: local (host), docker (container), provisioner (Kubernetes)

**Skill format**:
- SKILL.md with optional frontmatter (version, author, compatibility)
- Progressive loading (only when task needs them)
- Install via Gateway: POST /skills/install

**Testing**:
- Regression coverage: Docker sandbox mode detection, provisioner kubeconfig-path handling
- Gateway conformance: Embedded client dict responses validated against Pydantic models

## ANTI-PATTERNS

| Forbidden | Why |
|-----------|-----|
| Hardcoded API keys | Use env vars or config.yaml with `$VAR` expansion |
| Blocking I/O in async context | FastAPI + LangGraph are async-first |
| Skipping sandbox isolation | Security boundary for untrusted code execution |
| Modifying backend/AGENTS.md or frontend/AGENTS.md | Those are subdirectory-specific; this is the root AGENTS.md |
| Committing .env or config.yaml | Secrets and local config stay local |
| Direct LangChain imports in app/ | Use harness abstraction (models/factory.py) |
| Mixing publishable and unpublished code | harness/ is PyPI-ready, app/ is deployment-specific |

## COMMANDS

```bash
# Local development
make check                          # Verify Node.js 22+, pnpm, uv, nginx
make install                        # Install backend + frontend deps
make dev                            # Start Gateway (8001), LangGraph (2024), Frontend (3000), Nginx (2026)

# Docker development (hot-reload)
make docker-init                    # Pull sandbox image (once)
make docker-start                   # Start services (auto-detects sandbox mode)

# Docker production
make up                             # Build images + start all services
make down                           # Stop and remove containers

# Configuration
make config                         # Generate config.yaml + .env from templates

# Testing
pytest backend/tests/               # Run backend tests
pnpm test                           # Run frontend tests (from frontend/)

# Access
http://localhost:2026               # Nginx reverse proxy (production)
http://localhost:3000               # Frontend dev server (local dev)
http://localhost:8001               # Gateway API (local dev)
http://localhost:2024               # LangGraph Server (local dev)
```

## NOTES

- **Ground-up rewrite**: DeerFlow 2.0 shares no code with 1.x (maintained on `main-1.x` branch)
- **Harness vs App split**: packages/harness/deerflow/ is publishable, app/ is deployment-specific
- **Sandbox provider pattern**: Abstract base class with local/docker/provisioner implementations
- **Virtual path system**: /mnt/user-data/ (uploads, workspace, outputs), /mnt/skills/ (public, custom)
- **Subagent isolation**: Each sub-agent runs in its own context (no cross-contamination)
- **Memory system**: LLM-based extraction, debounced queue, 5-category facts (profile, preferences, knowledge, patterns, context)
- **Channel auto-start**: Telegram (long-polling), Slack (Socket Mode), Feishu (WebSocket) start when configured
- **MCP OAuth**: Supports client_credentials and refresh_token flows for HTTP/SSE MCP servers
- **Embedded client**: DeerFlowClient provides in-process access without HTTP services
- **Gateway conformance**: Embedded client responses validated against Gateway Pydantic models in CI
- **Skill archives**: .skill files with optional frontmatter (version, author, compatibility)
- **Follow-up suggestions**: Gateway normalizes plain-string and block/list-style model output before JSON parsing
- **InfoQuest integration**: BytePlus intelligent search and crawling toolset
- **Claude Code skill**: claude-to-deerflow skill for terminal interaction with running DeerFlow instance
