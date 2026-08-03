# Local model landscape — August 2026 (M5 Pro, 18-core, 64GB)

Research snapshot informing the OMP model roles. Verify Ollama tags before
pulling; benchmark numbers are from the cited sources, not measured here.

## Recommended stack

| Model | Size (quant) | tok/s (M5 Pro) | Best at | Weak at |
|---|---|---|---|---|
| **Qwen3-Coder-Next** (80B MoE, 3B active) | ~46GB Q4 | ~15–18 | agentic code edits, multi-file refactors, long-horizon (256K ctx) | occasional empty tool calls |
| **Qwen 3.6 35B-A3B** (installed) / 27B dense | ~17–23GB Q4 | ~20–25 | scouting, summarization, code review — best quality-per-token | heavy multi-file edits |
| **Devstral-Small** (24B) | ~14GB MLX 6-bit | ~18–22 | reliable tool-calling, GitHub-issue-style fixes, 256K ctx | — best local tool-caller |
| **GPT-OSS-20B** (installed) | ~11GB Q4 | fastest | fast drafts, cheap first-pass, reliable tool calls | weak multi-step autonomy |

Excluded: GLM-5.2 (needs ≥239GB even at 2-bit) and Kimi K2.7 (≥339GB) — no
64GB deployment path.

## Runtime

MLX now beats llama.cpp by ~30–40% on M5 (neural accelerators). Ollama 0.19+
auto-selects the MLX backend — current setup is already right. LM Studio /
mlx-lm direct are alternatives, not needed.
Sources: https://ollama.com/blog/mlx, https://yage.ai/share/mlx-apple-silicon-en-20260331.html

## Job routing (as wired in `~/.omp/agent/config.yml`)

- `scout` / `librarian` → qwen3.6:35b — free read-heavy lanes.
- `sonic` (mechanical edits) → qwen3-coder-next — free, agentically trained.
- Consider adding `ollama pull devstral:24b` (~14GB): the most reliable local
  tool-caller; could take over `sonic` if qwen3-coder-next's empty-tool-call
  quirk bites. Can run concurrently with qwen3.6 (~30GB total).
- Concurrency note: qwen3-coder-next (~46GB) cannot co-reside with the 35B;
  Ollama will swap. Keep scout lanes on the smaller models when running the
  80B.

Full scout report: sources include https://huggingface.co/Qwen/Qwen3-Coder-Next,
https://huggingface.co/mistralai/Devstral-Small-2505,
https://huggingface.co/openai/gpt-oss-20b, https://unsloth.ai/docs/models/glm-5.2
