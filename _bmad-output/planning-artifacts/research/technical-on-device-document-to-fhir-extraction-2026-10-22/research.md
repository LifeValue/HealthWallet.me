---
title: 'Technical research: on-device document-to-FHIR R4 extraction, what changed since May 2026'
type: 'technical'
topic: 'On-device document-to-FHIR R4 extraction: what changed since May 2026'
decision: 'Swap or add an on-device VLM (and possibly the runtime); invest in LoRA on own scan-to-FHIR pairs; harden structured JSON output; build a mapping-accuracy benchmark'
shape: 'select (model + runtime) / explore (LoRA, structured output, benchmark)'
source: 'native run (deep preset: 3 rounds, 13 research assistants + 1 verifier)'
status: complete
preset: 'deep'
validation: 'normal'
claims_verified: 13
claims_unverified: 15
claims_disputed: 1
claims_overturned: 0
created: '2026-10-22'
updated: '2026-10-22'
refresh_before: '2027-04-22'
---

# Technical research: on-device document → FHIR R4 extraction, what changed since May 2026

**Decision this research serves:** whether to swap or add an on-device vision-language model, and possibly the runtime; whether to invest in LoRA on our own scan→FHIR pairs; how to harden structured JSON output; and how to benchmark mapping accuracy.

**Requirements frame (from the codebase, not from research):**
- *Hard gates:*
  - Fully on-device and offline.
  - Usable from Flutter on iOS, Android, macOS and Windows.
  - Commercial licence.
  - About 4B parameters or fewer.
  - Fits the Lite tier (about 1.5 GB total, phones with <6 GB RAM) or the advanced tier (about 3.3 GB, ≥6 GB RAM).
- *Weighted preferences:*
  - Document extraction accuracy.
  - Medical coding knowledge.
  - JSON compliance.
  - EN/ES/DE/RO coverage.
  - Size and latency.
  - Runtime readiness, that is, credit for not migrating.
  - Licence burden.
- *Baseline:* `llamadart` 0.6.8 (llama.cpp) with Qwen3-VL-2B and MedGemma 4B, using a generic JSON-array GBNF grammar.

**Conventions:** confidence is per claim and marked where below high. "Vendor" means the model's publisher measured it.

## Executive summary

**What to do:**
1. Upgrade the runtime we already use, not switch it.
2. Make the JSON output schema-specific.
3. Build our own benchmark *before* changing models or training a LoRA.
4. Benchmark NuExtract3 against MedGemma for the advanced tier. Keep Qwen3-VL-2B on the Lite tier and benchmark Qwen3.5-2B and NuExtract 2.0-2B against it.
5. Defer LoRA until the benchmark exists, and prove a LoRA works alongside the vision projector first.

**The findings that drive this:**

1. **The runtime moved under us, inside the same package.** `llamadart` went from our 0.6.8 to 0.15.6 [1]. It now drives llama.cpp and Google's LiteRT-LM behind one Dart API, with JSON-schema output that raises an error on unsupported schemas instead of silently ignoring them, and runtime LoRA loading [2][3].
   - LiteRT-LM *may* be faster on phone GPUs: 61 vs 39 tok/s in one independent text-only test, which our verifier could not corroborate (single source, unverified) [4].
   - No official Qwen or MedGemma vision builds were found for it (medium confidence), and it has no constrained JSON through `llamadart` yet [5].
   - Apple's and Android's built-in models cover only some platforms. The Android one is also beta and capped at 4,000 tokens [6].
   - **Upgrade `llamadart`, keep llama.cpp as the default backend, and evaluate LiteRT-LM as a second one.**
2. **Small models fail mostly on format, and the cheap fixes come first.**
   - Below 4B, VAREX found models returning the schema instead of values. Inlining `$defs` alone lifted Qwen3-VL-2B from 27% to 92% on affected documents [7].
   - Hard schema constraints at ≤3B guarantee validity but can cost accuracy; "reason free, constrain late" (let the model reason in free text, then constrain only the final answer) recovers most of the lost accuracy [8]. An independent benchmark confirms the cost [9], and a second independent study agrees on the fix (D3).
   - **Use a flat intermediate schema with required fields first, constrain the final pass, then validate FHIR on the device** [10].
3. **Gains from model upgrades are smaller than vendor cards suggest.**
   - Qwen3.5-2B's claimed ~15-point document lead over our Qwen3-VL-2B shrinks to a tie on an independent benchmark [11].
   - MedGemma 1.5's extraction gains are on internal PDF sets; on the public image set it equals MedGemma 1 [12].
   - The one candidate with an extraction-specific edge is **NuExtract3**, a Qwen3.5-4B fine-tune under Apache-2.0. It produces about one-eighth of its base model's failed outputs (27 vs 229), though only on its vendor's own benchmark [13].
   - **Benchmark NuExtract3 on the advanced tier, and don't swap the Lite model yet.**
4. **LoRA is cheap to train and risky to ship.**
   - Measured gains are large: 2B reading accuracy went from 62% to 88% on 176 forms [14]. Compute is tens of GPU-hours at most [15].
   - Models trained on templated synthetic data collapse on unseen layouts: F1 fell from 0.98 to 0.59 [15].
   - Three targeted searches found no report of a LoRA working alongside a vision projector in llama.cpp; llama.cpp's `llama-mtmd-cli` merely accepts both flags [16].
   - Apple's adapter path is obsolete on iOS and macOS 27 [17].
   - **Defer LoRA until the benchmark exists, and run the LoRA + projector experiment first.**

**Biggest caveat:** no public benchmark pairs medical document images with FHIR, in any language [18]. Almost every model number here is vendor-reported. So the first deliverable is our own EN/ES/DE/RO benchmark (D4). Every other decision in this report is provisional until it exists. 7 of 23 load-bearing claims are already past their freshness bar (see the Staleness map).

## D1a. Model candidates: swap or add?

**Bottom line.**
- **Advanced tier (≥6 GB RAM):** there is a real candidate to benchmark against MedGemma. **NuExtract3** is NuMind's document-extraction fine-tune of Qwen3.5-4B, released May 2026 under Apache-2.0. It is the same size class as MedGemma 4B, uses an architecture llama.cpp already supports, and carries no obligations under Google's Health AI Developer Foundations (HAI-DEF) terms.
- **Lite tier:** the evidence does **not** justify swapping Qwen3-VL-2B yet. Its successor, Qwen3.5-2B, ties with it on the only independent document benchmark and is about 0.45 GB larger.
- **Every document score below is vendor-reported unless marked otherwise.** The matrix is a prior for D4's benchmark, not a substitute for it.

**What changed since May 2026.**
- **Qwen:** nothing ≤4B. The current small line is still Qwen3.5 0.8B–9B from March 2026 [19].
- **Google:** MedGemma 1.5 4B (January 2026) is the latest MedGemma, and no Gemma 4-based MedGemma exists [12]. Gemma 4 E2B/E4B arrived in April under Apache-2.0 [20].
- **Released inside the window:**
  - NuExtract3 (about May 2026) [13].
  - MiniCPM-V 4.6 (about 1B, 2026-05-11) [21].
  - PaddleOCR-VL-1.6 (0.9B, 2026-05-28), a page parser that turns images into text and tables rather than extracting fields [22].
  - A wave of OCR-only models supported in llama.cpp [23]. These would need a second pass to produce FHIR.

**What the evidence says about each.**
- **Qwen3.5-2B/4B.** Qwen's own card shows big gains over Qwen3-VL-2B: OmniDocBench 80.9 vs 65.9 [24]. The 4B scores 86.2 [25].
  - The independent PureDocBench (Sept 2026) finds the two 2B models **essentially tied**: 62.46 vs 62.09. Qwen3.5-2B is ahead only on real-world photos, 55.92 vs 54.09 [11]. **The vendor gap is disputed.**
  - llama.cpp has supported Qwen3.5 vision since 2026-02-10 [26].
  - Q4_K_M + mmproj (the vision projector file) is about 1.95 GB for the 2B [27] and about 3.4 GB for the 4B [28].
  - A report of gibberish output from Qwen3.5-2B on an Adreno Vulkan GPU was closed stale without a fix [29]. `llamadart` defaults Android to CPU, so it matters less there (D1b).
  - Its JSON compliance on images is untested. Its predecessor Qwen3-VL-2B was non-compliant on 56% of image inputs in VAREX (D2) [7], so its JSON-compliance score of 2 in the matrix below is a family prior, not a measurement.
- **NuExtract3 (4B).**
  - On NuMind's own extraction benchmark it scores 0.651 against 0.417 for its base Qwen3.5-4B, with 27 against 229 failed outputs. Gemma 4 E4B scores 0.538 [13].
  - These are vendor numbers on the vendor's own set. They match the independent finding that small models fail mainly on format, which extraction training fixes [30].
  - No official GGUF exists. A community Q4_K_M is 2.71 GB plus a 676 MB mmproj [31].
  - Its languages are listed only as "multilingual".
  - Its predecessor NuExtract 2.0 has an MIT 2B build on Qwen2-VL-2B [32], a possible Lite-tier wildcard (GGUF not checked).
- **MedGemma 1.5 4B.** I re-checked the card. Compared with MedGemma 1, lab-report extraction rose from 25 to 64 macro F1 on an internal dataset ("EHR 4"), and from 78 to 91 on another. On the one **public image→JSON** set (Mendeley lab-report PNGs), MedGemma 1 and 1.5 both score **85**, and plain Gemma 3 4B scores 83. Plain Gemma 3 4B also *beats* MedGemma 1 on all three internal PDF sets: 84/61/41 vs 78/50/25 [12].
  - The gains are on PDFs and internal data, not clearly on photos. No independent evaluation was found.
  - It stays under HAI-DEF terms (D2) [33].
  - It is a probable drop-in for MedGemma 1, since both use the Gemma 3 architecture.
  - One unverified forum report says its Q8_0 quantised build fails to produce valid JSON on dense pages [34].
- **Gemma 4 E2B.** 2.3B effective but 5.1B total parameters, so the GGUF is 3.11 GB before the mmproj [20]. Through LiteRT-LM it is 2.58 GB with about 1.45 GB of memory (text) [35].
  - Its only document score is an edit distance (lower is better) that can't be compared with Qwen's [20].
  - In practice it is a LiteRT-LM-only option, and that path has no JSON constraints through `llamadart` yet (D3).
- **Screened out or watch list.**
  - MiniCPM-V 4.6: claims Qwen3.5-2B-level OCR with no numbers [21].
  - InternVL3.5-2B `.litertlm`: 1.61 GB, Apache-2.0 [36], but LiteRT-only and no document scores.
  - LFM2.5-VL-1.6B: custom licence, no Romanian [37].
  - PaddleOCR-VL-1.6: a parser front-end, not an extractor [22].
  - Cut on the ≤4B gate: Qwen3.6/3.8 (27B+) and Phi-4-reasoning-vision (15B).

**Scoring matrix.** Scores are 1–5 and weights sum to 100. Each total is the weighted sum, scaled to 100. The scores are my judgement from the evidence above; re-weight freely. "Runtime readiness" is the switching-cost credit for running under `llamadart` 0.15's llama.cpp backend.

| Criterion (weight) | Qwen3-VL-2B *(Lite, now)* | Qwen3.5-2B | MiniCPM-V 4.6 | InternVL3.5-2B (LiteRT) | MedGemma 1 4B *(Adv., now)* | MedGemma 1.5 4B | Qwen3.5-4B | **NuExtract3 4B** | Gemma 4 E2B (LiteRT) |
|---|---|---|---|---|---|---|---|---|---|
| Doc extraction accuracy (30) | 3 | 3.5 | 2.5 | 2.5 | 3 | 3.5 | 4 | 4.5 | 3 |
| Medical knowledge/coding (15) | 2 | 3 | 2 | 2 | 4 | 4.5 | 3 | 3 | 3 |
| JSON/schema compliance (15) | 2 | 2 | 2 | 1 | 2.5 | 3 | 2.5 | 4.5 | 1.5 |
| EN/ES/DE/RO (10) | 3 | 4 | 2 | 2 | 2 | 2 | 4 | 3.5 | 4 |
| Size/latency fit for its tier (15) | 5 | 3 | 5 | 5 | 4 | 4 | 4 | 4 | 4 |
| Runtime readiness (10) | 4 | 4 | 3 | 2 | 5 | 4 | 4 | 3 | 2.5 |
| Licence burden (5) | 5 | 5 | 5 | 5 | 2 | 2 | 5 | 5 | 5 |
| **Weighted total /100** | **64** | **66** | **57** | **52** | **65.5** | **69.5** | **73.5** | **79.5** | **61.5** |

**Verdict.**
- **Advanced tier.**
  - **Pick to benchmark: NuExtract3.**
  - **Runner-up: Qwen3.5-4B**, NuExtract3's base model and so the fair control. It wins if NuExtract3's community GGUF quantises badly, or if the extraction fine-tune hurts medical coding.
  - **Keep MedGemma 1.5 4B** as the drop-in upgrade for the current MedGemma 1. Its edge is medical terminology. It wins if D4 shows that coding accuracy matters more than field accuracy, at the price of HAI-DEF obligations.
  - **Strongest argument against the pick:**
    - Its lead rests entirely on NuMind's own benchmark.
    - It depends on a single community GGUF.
    - It comes from a small vendor with an unstated language list.
  - **Cheapest hedge:** NuExtract3 and Qwen3.5-4B share an architecture, so one runtime path serves both. Swapping is a new `AiModelConfig` entry, not new code.
- **Lite tier.** Beyond the no-swap call above, test NuExtract 2.0-2B (MIT) as a wildcard. Re-screen when an extraction-tuned Qwen3.5-2B or a Gemma 4-based MedGemma ships.

## D1b. On-device runtime: is llama.cpp/llamadart still the way?

**Bottom line:** yes, for now, but not the version we ship. The landscape did shift. Google's LiteRT-LM is now a credible cross-platform runtime with vision, and it may be faster than llama.cpp on phone GPUs (one independent text benchmark, not corroborated). Apple added image input to its on-device model.

None of the alternatives beats llama.cpp on the combination we need:
- vision for *our* models (Qwen, MedGemma);
- grammar-constrained JSON;
- runtime LoRA;
- Windows support;
- a production Flutter path.

And `llamadart` itself now wraps LiteRT-LM. **Upgrade `llamadart` from 0.6.8 to 0.15.x, and evaluate LiteRT-LM as a second backend in the same package**, rather than switching runtimes.

**At a glance.**

| Runtime | iOS | Android | macOS | Windows | Our VLMs | Constrained JSON | Runtime LoRA | Fit |
|---|---|---|---|---|---|---|---|---|
| llama.cpp through llamadart 0.15 | Metal | CPU (Vulkan experimental) | Metal | Vulkan/CUDA | Qwen3.5, Gemma 3/4 named; Qwen3-VL/MedGemma untested | Yes (fails loudly) | Yes | **Baseline: upgrade** |
| LiteRT-LM (through llamadart or native) | Yes | GPU/NPU | arm64 | x86_64 | Gemma 4 only (official) | Upstream yes; not through llamadart yet | One adapter; buggy | **Evaluate as second backend** |
| Apple Foundation Models / Core AI | iOS 27 | No | macOS 27 | No | Apple model or Core AI export | `@Generable` | Toolkit discontinued | Partial; watch |
| ML Kit Prompt API | No | Gemini Nano devices | No | No | Gemini Nano | Alpha | No | Reject (beta, 4K-token cap) |
| Cactus, ONNX Runtime GenAI, ExecuTorch | partial | partial | partial | partial/none | limited | limited | varies | Reject for now |

**llamadart moved a long way.**
- **Current release.** 0.15.6 (about 2026-10-21, MIT) drives both llama.cpp (GGUF + mmproj) and LiteRT-LM (`.litertlm`) behind one Dart API, with LoRA, grammar and JSON-schema `responseFormat`, and tool calling [1].
- **What our pin bundles.** 0.6.8 shipped llama.cpp b8480 [38].
- **Upgrade cost.** Several breaking releases lie in between [38]:
  - 0.7.1 raises the minimum to iOS 16.4 / macOS 14.
  - 0.11 is the largest API break.
  - 0.14 is an ABI break, and unsupported schemas now throw.
- **Model coverage.** The changelog names Qwen3.5, Gemma 3/4 and GLM-OCR multimodal work, but **never names Qwen3-VL or MedGemma** [38]. Our current models probably keep working through generic mmproj support, but that is unverified: test before upgrading.
- **GPU support.** Metal on Apple and Vulkan or CUDA on Windows. Android Vulkan is still experimental, the default is CPU, and there is no OpenCL/Adreno backend [1]. That CPU default makes a reported 2.7x slowdown in CPU-only Android vision encoding relevant to us: an upstream regression reported in August 2026 that we haven't verified [39].
- **Bus factor.** It looks like one maintainer: 78 stars and 124 open issues, but releases nearly every day [40].

**LiteRT-LM is the one credible alternative.**
- **Coverage.** Google-backed and Apache-2.0. Releases v0.16–v0.18.1 landed between August and October 2026 [41]. It runs on all four targets with GPU/NPU and vision input, but its Flutter support is "community" only [42].
- **Speed.** Gemma 4 E2B as `.litertlm` is 2.58 GB and decodes at 56.5 tok/s on an iPhone 17 Pro GPU using about 1.45 GB of memory. Those are text-only numbers [35].
- **The one independent comparison** used Gemma 4 E2B text on an iPhone 17 Pro [4]:

  | | LiteRT-LM | llama.cpp (Q4_K_M) |
  |---|---|---|
  | Decode | 61.1 tok/s | 38.8 tok/s |
  | GSM8K | 86% | 76% |

  Over 10 minutes of sustained load, LiteRT-LM and the other runtimes tested lost speed: LiteRT-LM and MLX half or more, Core ML a third; llama.cpp was not measured. The author warns that speed ratios from different test sessions can't be compared, and our verifier found no second phone comparison. **No one has published a cross-runtime benchmark of image encoding**, which dominates our workload [4].
- **Gaps for us.**
  - No official Qwen3-VL, Qwen3.5-vision or MedGemma `.litertlm` builds were found (snippet search of litert-community; medium confidence). Vision coverage is Gemma 4 plus community InternVL [36], Qwen2-VL and Ovis builds.
  - `llamadart`'s LiteRT-LM backend allows one LoRA at scale 1.0, has no grammar constraints on iOS [38], and has no JSON constraints at all yet [5].
  - LoRA on LiteRT-LM has an open no-op bug [43].

**OS-provided models cover only some platforms and are not general enough.**
- **Apple.** At WWDC 2026 (2026-06-08), Apple added image input to Foundation Models and announced a new Core AI framework [44], which an independent benchmark author describes as Core ML's successor [4]. Core AI needs iOS/macOS 27+ [45]. Apple's own adapter path is closing (see D2) [46]. No Android or Windows.
- **Android.** The ML Kit Prompt API (Gemini Nano) takes image and text with alpha structured output, but it is beta [47], Gemini Nano devices only, and limited to under 4,000 tokens [6]. An "English and Korean only" validation note appeared only in a search snippet (unverified). Even if that note is wrong, a 4K-token cap and beta status rule it out for multi-page documents.

**Others.**
- **flutter_edge_ai** (formerly flutter_gemma) wraps LiteRT-LM, ONNX Runtime, llama.cpp through `llamadart`, and the OS models. It documents no JSON constraints and can't run LiteRT-LM and llama.cpp together on macOS [48].
- **Cactus's** licence ends free use above USD 2M in revenue or funding, and it has no Windows build [49].
- **ONNX Runtime GenAI** runs Qwen3-VL only through a workaround [50].
- **ExecuTorch and MLC LLM:** no Flutter path or 2026 VLM evidence found.

## D2. Fine-tuning and LoRA on our own document → FHIR pairs

**Bottom line:** fine-tuning a 2–4B VLM for document extraction is cheap, well-tooled and gives large measured gains. Two risks dominate:
- **Layout overfitting:** models fine-tuned on templated synthetic data collapse on differently rendered documents.
- **Shipping:** nobody has shown a LoRA adapter working with a vision projector in llama.cpp, so the low-risk path is to freeze the vision layers, or merge the adapter into the model and re-export it.

Free wins from schema design (see D3) come first and are much cheaper.

**Measured gains, and the catch.**
- **A Sept 2026 study** fine-tuned Qwen2.5-VL-3B and 7B with LoRA (r16/α32, attention + MLP) on about 3K synthetic bank checks [15].
  - In-distribution F1 rose to about 0.98: 3B went 0.847→0.983, beating GPT-5 zero-shot at 0.928.
  - On a differently rendered check set, the fine-tuned 3B fell to 0.593 [15].
- **RAPTOR+ (June 2026)** fine-tuned Qwen3-VL-2B, 4B and 8B on just 176 synthetic clinical forms [14].
  - 2B reading accuracy rose from 62.3% to 88.3%.
  - Strict per-document safety reached only 21% at 2B and 26% at 4B, against 61% at 8B [14]. Fine-tuning narrows the size gap but does not close it.
- **A synthetic-to-real gap appears again** in a care-transition study: about 97% on synthetic documents, about 85% on real scans [51] (medium confidence).
- **Implication:** training data must mix real or realistically degraded scans across document families and the four languages, not just one rendered template.

**A cheaper first step.** Fix the prompt and schema first (see D3, where the VAREX evidence sits); extraction training adds on top [30].

**Data.**
- **No public dataset pairs medical document images with FHIR.** Synthea is the only licence-clean source of FHIR ground truth: Apache-2.0, FHIR R4, covers all target resource types [52].
  - Its demographics are US-only [52].
  - There is no maintained European fork. A German study found only 7 of 16 Synthea resource types matched German core profiles without conversion [53].
- **A realistic pipeline** therefore looks like this: Synthea or our own FHIR → localised ES/DE/RO document templates → rendered and degraded images, plus a de-identified real set. That is our inference.
- **Reward functions for RL fine-tuning (GRPO)** that score schema validity exist only as code patterns, with no published small-VLM results [54].

**Tooling and cost (as of 2026-10-22).**
- TRL v1.16.0 does VLM supervised fine-tuning with PEFT LoRA [55].
- Unsloth covers Qwen3.5 0.8B–122B vision fine-tuning. It needs about 5 GB VRAM for bf16 LoRA at 2B and about 10 GB at 4B, and advises against 4-bit QLoRA for Qwen3.5 [56].
- LLaMA-Factory lists Qwen3-VL 2B/4B, Qwen3.5, Gemma 3/3n and MiniCPM-V 4.6 [57].
- MLX-VLM does LoRA and GRPO on Apple Silicon [58].
- Google ships official MedGemma LoRA and RL notebooks [59].
- Measured cost: 6–14 A100-80GB GPU-hours for 3B/7B on about 3K samples [15]. That is tens of dollars per run on rented GPUs, which is our arithmetic; no published price exists. The real cost is building the dataset, not compute.

**Shipping the adapter, per runtime.**

| Runtime | Runtime LoRA | With vision | Notes |
|---|---|---|---|
| llama.cpp | Yes: multi-adapter, scaled, per-request hot-swap [60] | `llama-mtmd-cli` accepts `--lora` and `--mmproj` [16], but no end-to-end report found either way | Merging a LoRA and re-converting the mmproj gave "@" output in a 2025 Qwen2.5-VL report, closed stale [61] |
| llamadart 0.15.x | `setLoraSource`, `removeLoraSource`, `clearLoras`; adapters from URL or `hf://` with resumable download [3] | Undocumented: test it | LiteRT-LM backend: one text LoRA at load only [3] |
| LiteRT-LM | Architecturally yes | Open bug: a LoRA on Gemma 4 E2B GPU loads but changes nothing [43] | Not production-ready for our use |
| Apple Foundation Models | Toolkit 26.0.0 is the **last release** and does not work on OS 27+ [46] | Adapter docs are text-only | Needs an entitlement and is about 160 MB per OS-model version. A dead end for now |

Unsloth trains the vision layers by default and documents no mmproj export [62][56]. A downloadable runtime adapter therefore means training with `finetune_vision_layers=False`. Otherwise, merge the adapter and re-export both the model GGUF and the mmproj, at the cost of users re-downloading the whole model.

**Licences.**
- Qwen3.5 is Apache-2.0 [24], and so is Gemma 4 per its model card [20]. Google's blog post announcing Gemma's move to Apache-2.0 was seen only in search results [63].
- A MedGemma LoRA or merge is a HAI-DEF Model Derivative. Shipping it means [33]:
  - Flowing the use restrictions down into the app's terms.
  - Giving users a copy of the Agreement and shipping a Notice file.
  - Seeking health-regulator authorisation where applicable.
  - Never using it in a way that makes Google a medical-device "manufacturer".

  That is a real cost a Qwen or Gemma 4 base avoids.
- MedGemma's outputs are not themselves Model Derivatives, but under the HAI-DEF terms a model trained on them to perform like MedGemma is one [33]. Distilling MedGemma labels into a Qwen model can therefore inherit HAI-DEF terms.

## D3. Structured, grammar-constrained JSON output

**Bottom line:** keep the intermediate-schema-then-map design, and make the grammar schema-specific instead of a generic "JSON array of objects". Do this through `llamadart` 0.15's `responseFormat`, with:
- a flat schema: no `$defs`, required fields first, enums for closed value sets;
- a "reason free, constrain late" step for the small model;
- FHIR validation on the device after mapping.

Strict constraints guarantee *form*. They can cost *accuracy* at ≤3B, which is exactly our size class.

**Why the schema matters most at our size.** VAREX found that small VLMs fail mostly on format. Non-compliance jumps from 2–3% on flat schemas to 68–69% when the schema uses `$defs`. Just inlining `$defs` lifted Qwen3-VL-2B from 27.4% to 91.8% on that subset. Qwen3-VL-2B was non-compliant on 56% of image inputs, against 17% of text inputs [7]. Fix the prompt and schema before training; extraction training adds on top (D2).

**What llama.cpp does today.**
- **The built-in schema converter.** It still handles only a subset of JSON Schema and **silently skips** what it can't handle: nested `$ref`, `anyOf` mixed with properties, number bounds, `prefixItems`. The schema also isn't injected into the prompt, so the prompt must still describe the structure [64].
- **2026 issue status (checked 2026-10-22):**
  - **Closed:** large `$ref`/`$defs` schemas silently dropping the constraint (closed as completed, but no fix commit was identified, so re-test) [65], and the grammar not applying when the model's thinking mode is on [66].
  - **Not fixed:** the deep-nesting crash (CVE-2026-52130), closed as "not planned" with its nesting-cap PR still open, and a `minItems` OOM, still open [67].
  - **New and still open:** an optional property listed *before* a required one is silently dropped. The output is still valid JSON [68].
- **llguidance is the stronger engine** [69]. It errors on unsupported schemas instead of dropping them, keeps property order, and costs about 50 µs per token. It needs a Rust build flag.

**What llamadart 0.15.6 changes for us.**
- **Its own converter.** It ships its own Dart port of the schema-to-grammar converter, so the upstream server crash bugs don't apply directly [2].
- **Fails loudly.** Schemas it can't represent (untyped properties, non-local `$ref`, too-deep nesting, cycles) **throw** instead of degrading silently, and grammars over the repetition limit are rejected before generation [2].
- **Inherits the ordering rule.** Its object rule uses the same required-first split, so the optional-before-required field-order bug above (llama.cpp #30321) probably applies. That is an inference from the code: test it, and put required fields first.
- **No llguidance** [2].
- **No constraints on the LiteRT-LM backend yet** (open, P2), although upstream LiteRT-LM now exposes them [5].

**Accuracy: constraints help form, can hurt content.**
- **Small models gain.** On 0.6–4B models, constraints took validity to 100% and lifted content accuracy, for example Llama-3.2-3B from 0.777 to 0.991. They fix type errors but not semantic ones [70]. At 8B, constrained decoding was neutral to slightly positive on accuracy [71].
- **The "constraint tax."** A May 2026 study found that at ≤3B, a hard answer-only schema gave 100% validity but cost 8.7 points of accuracy on average, up to 20 points for individual models and 43.5 on a tool-call task. Its fix is to **"reason free, constrain late"**: delayed constraints reached 40.7% against 26.8% for answer-only [8].
- **Independent confirmation.** StructureBench (IJCAI 2026) tested 11 on-device models of 0.5–8B. It found constraints enforce structure but "may even degrade performance for smaller models" [9]. A separate "format tax" study puts most of the loss on format *instructions* rather than the decoding mask, and also recovers accuracy by separating reasoning from formatting [72]. So the direction is verified by independent groups; the exact sizes are not.
- **Draft-then-constrain.** Draft freely, then decode constrained with the draft in context. It gains up to 24 points at 1–1.5B [73].
- **Caveat.** The constraint-tax and draft-then-constrain studies both use reasoning tasks, not document extraction, so the transfer is a hypothesis to test in D4's harness.
- **Already partly built.** Our pipeline already has a free-text OCR path, which is a natural "draft" for the constrained pass. That is our inference.

**FHIR-specific evidence.**
- **CFG4FHIR (MIE 2026)** builds grammars from FHIR R5 schemas with relaxed key order [74].
  - It reaches 76.5% valid resources, against 41.2% with JSON-schema guidance and 17.6% unguided.
  - That is on only 17 cases with a **70B** model.
  - Its repo has no licence, and enums can come out "valid but wrong" [75].
- **Infherno** rejected a full FHIR grammar as too costly [76].
- **Taken together**, this supports our current design: a small intermediate schema constrained by grammar, then a deterministic FHIR mapping. Not a full FHIR grammar on a 2B model.
- **On-device validation after mapping.** `fhir_r4_validation` 0.14.0 (2026-10-16) checks structure, cardinality, bindings and FHIRPath invariants in Dart. Its models are R4B, not R4, so its fit for our R4 resources needs checking [10].

**Other runtimes.**
- **Apple Foundation Models** now combines on-device image understanding with `@Generable` guided generation, and accepts Core AI-exported custom models [77]. Apple platforms only.
- **LiteRT-LM** offers llguidance constraints (JSON Schema, Lark, regex) in C++ [78]. Reported bugs, status unverified: end-of-output allowed inside JSON strings, and no spaces from SentencePiece models [79].

## D4. Benchmarking mapping accuracy

**Bottom line:** no public benchmark exists for turning document photos or scans into FHIR, in any language. The 2026 extraction benchmarks have, however, converged on a scoring design that can be reused almost as-is. So this is a build-our-own job on well-trodden methodology; Recommendation 3 assembles the harness specification.

**Metrics that have converged in 2026.**
- **Matching and F1.** LlamaIndex's ExtractBench pairs predicted records to gold records one-to-one using the Hungarian algorithm (an optimal one-to-one assignment). Its matching cost is the number of mismatched subfields. It flattens the output to one cell per scalar and scores micro-F1 per document, then averages across documents [80].
  - A missing key counts the same as an explicit null. Every scalar in the schema counts toward both precision and recall, so a correct null earns credit and an invented value costs precision [80].
  - The evaluator is Apache-2.0 and actively maintained [81].
- **Per-field comparators.** Contextual AI's ExtractBench, a different benchmark with the same name, declares a comparator for each field in the schema: exact, case-insensitive, fuzzy, numeric tolerance, and an LLM judge only for free text [82].
- **Omissions and hallucinations.** The same benchmark gives every value one of three states, present, null or MISSING, which yields clean omission and hallucination rates [82].
- **Invalid output.** Invalid JSON stays in the denominator. In that benchmark it dominated failures: validity was 37–51% [82].
- **FHIR validity rate.** A FHIR-specific paper scores validity as the share of bundles the HL7 validator passes with no errors, and scores coding by exact code match. Its headline numbers are partly placeholders by the authors' own note, so only its method is usable [83].
- **No FHIR-specific matching metric.** No FHIR paper retrieved defines resource-level matching plus field-level F1. That part has to be designed in-house.

**Adapting the metrics to FHIR.** LlamaIndex ExtractBench's strict typing ("1,000" ≠ 1000) and its order-sensitive scalar lists would mis-score FHIR data. Three things need custom comparators:
- `valueQuantity` needs a numeric comparison after unit conversion. NLM's ucum-lhc provides UCUM validation and conversion, but its custom licence needs review [84].
- Lists like `coding[]` and `given[]` need set semantics instead of order-sensitive comparison.
- FHIR partial dates (YYYY or YYYY-MM) need a comparison that respects their precision.

Partial credit for codes based on the code hierarchy is published only for ICD [85]. Tiered credit for SNOMED, LOINC and RxNorm would be our own design. For example: exact code = 1, matching display text but no code = partial, same RxNorm ingredient = partial.

**Datasets and harness tooling.**
- **Closest template: IBM's VAREX** (CVPRW 2026).
  - It generates 1,777 synthetic documents by filling templates, so ground truth is exact. Each document is offered as plain text, layout text, image, and layout text plus image [30].
  - Its headline finding, that models below 4B return the schema instead of values ("schema echo", costing 45–65 points), drives D2 and D3 [30].
  - VAREX's code is Apache-2.0. Its dataset licence is stated only as "permissive" [86].
- **Text→FHIR work exists but doesn't transfer.**
  - FHIR Workbench reports Note2FHIR F1 of only 0.04–0.36 [87].
  - CIRCA uses a deterministic FHIR mapper but needs credentialed MIMIC access [88].
  - flexpa/llm-fhir-eval shows a promptfoo harness with FHIRPath and validator assertions. It has no licence file, so reuse is not permitted by default, and it is barely maintained: copy the idea, not the code [89].
  - Infherno is text-only and also unlicensed [90].

**LLM-as-judge.** A 2026 scoping review of 49 healthcare studies found 73.5% did no risk-of-bias testing and 26.5% used no expert validators. It warns that a judge which shares blind spots with the system it grades can make errors look like agreement [91]. Use deterministic scoring for every coded or factual field, and a human-validated judge only for free text (dosage text, notes).

**Statistics.**
- Resample whole documents in a paired bootstrap. VAREX could not separate models within about 0.5 points even with 1,777 documents [30]. A clustered or hierarchical bootstrap handles fields nested in documents [92].
- No published "N documents to detect a 3–5 point F1 gap" exists for extraction. Card et al. recommend simulation-based power analysis [93]. The practical route is a pilot of 30–50 documents to estimate variance, then simulate the needed N. That is our inference, not a sourced figure.

**Measuring on devices.**
- llama.cpp's `llama-bench` measures only text throughput: no image-encode time, time-to-first-token or RAM [94]. Those need custom instrumentation.
- Thermal state must be controlled, because a few consecutive runs trigger CPU down-clocking [95].
- A 2026 Galaxy S25 Ultra study found only models up to about 3B gave usable interactivity under llama.cpp (medium confidence) [96].

## Cross-dimension insights

- **The runtime upgrade unlocks every other recommendation.** Schema-specific JSON (D3) needs `llamadart`'s `responseFormat` with its loud failures. A downloadable LoRA (D2) needs its `setLoraSource` API. Qwen3.5 and NuExtract3 (D1a) are validated on the Qwen3.5 code path, which 0.6.8 predates. So the 0.6.8 → 0.15.x migration comes first. Its breaking changes and the untested Qwen3-VL/MedGemma support (D1b) are the first risks to retire.
- **Format failure ties model choice, grammar and fine-tuning together.**
  - Small models lose most points on format [30].
  - Grammars fix form but can tax accuracy at ≤3B [8].
  - Extraction fine-tunes (NuExtract3, RAPTOR+) mostly fix format and localisation [13][14].
  - So the order is: schema design (free), then constrained decoding with a free-reasoning step, then an extraction-tuned base model, then our own LoRA. Measure each step on the D4 harness before moving to the next.
- **LiteRT-LM may be the answer on speed, but it opens the structured-output gap.** It may be faster on phone GPUs (one unverified test, D1b), but it loses constrained JSON and multi-LoRA through `llamadart` (D2, D3). Re-evaluate it once `llamadart` issue #174 (LiteRT-LM constraints) lands, or if Gemma 4 or InternVL3.5 win on D4.
- **Licence shapes the tier strategy.** MedGemma derivatives carry HAI-DEF obligations, including any model trained on MedGemma's outputs to perform like it [33]. An Apache-2.0 Qwen3.5 or NuExtract3 base avoids that for both shipping and LoRA.
- **The benchmark and the training data are the same asset.** A VAREX-style synthetic pipeline (Synthea → localised templates → rendered and degraded images) gives exact ground truth for both D4 and D2 [30][52]. Hold out real de-identified scans for testing, so the 0.98 → 0.59 synthetic-to-real collapse can't hide [15].

## Recommendations

In order of execution. Recommendations 1 and 3 can run in parallel; the schema change in 2 is measured on the harness from 3 before it ships.

1. **Upgrade `llamadart` from 0.6.8 to 0.15.x in a spike branch.**
   - Retire these risks first: the breaking APIs from 0.11 and 0.14, the iOS 16.4 / macOS 14 minimum, and whether Qwen3-VL-2B and MedGemma 4B still load with their mmproj on all four targets.
   - *Feeds:* architecture spine (runtime decision), roadmap risk.
   - *Confidence:* high on the package facts [38]. Model compatibility is unverified.
2. **Replace the generic `jsonArray` GBNF with a schema-specific `responseFormat`.**
   - Use one flat intermediate schema per pipeline phase: no `$defs`, required fields first, enums for closed sets.
   - Keep a free-text step before the constrained pass, either through the OCR text or a draft.
   - Then add a `fhir_r4_validation` pass after mapping, checking R4B vs R4 first.
   - *Feeds:* architecture spine (processing pipeline).
   - *Confidence:* high on mechanism [7][2]; medium on accuracy transfer, since the tax studies use reasoning tasks [8].
3. **Build the D4 benchmark before any model swap or training.**
   - Synthetic EN/ES/DE/RO documents with exact ground truth, plus a de-identified real hold-out.
   - Scoring: ExtractBench-style Hungarian matching and per-document F1, using its Apache-2.0 evaluator plus FHIR comparators (UCUM, code sets, partial dates).
   - Also report validity rate, omissions and hallucinations, and a document-clustered bootstrap.
   - Measure image-encode time, time-to-first-token and peak RAM on a device matrix.
   - *Feeds:* brief (feasibility), roadmap estimates.
   - *Confidence:* high on method [80][30].
4. **Benchmark the model candidates on the D4 harness.**
   - Advanced tier: NuExtract3 vs Qwen3.5-4B vs MedGemma 1.5 vs MedGemma 1 (current).
   - Lite tier: Qwen3.5-2B and NuExtract 2.0-2B against Qwen3-VL-2B (current).
   - *Feeds:* the AI model configuration.
   - *Confidence:* medium. The ranking rests on vendor numbers, and one was disputed [11].
5. **Treat LoRA as a later phase, gated on the benchmark.**
   - If pursued: train an Apache-2.0 base with vision layers frozen, so the adapter is a small text-side GGUF loadable through `setLoraSource`.
   - Prove LoRA + mmproj end to end in a half-day experiment first.
   - Mix real scans with synthetic ones.
   - *Feeds:* roadmap risk.
   - *Confidence:* medium on gains [14][15]; low on shipping, since there is no end-to-end evidence [16].
6. **Do not adopt the Apple Foundation Models, ML Kit Prompt API or Cactus paths for extraction.** Each fails a hard gate:
   - Apple is Apple-only, and its custom adapters are obsolete [17].
   - ML Kit is Android-only, beta and capped at 4K tokens [6].
   - Cactus has no Windows build, and its licence caps free use [49].
   - *Feeds:* architecture spine (runtime decision).
   - *Confidence:* high for Apple and Cactus, medium for ML Kit.

## Open questions

- **Do Qwen3-VL-2B and MedGemma 4B work on `llamadart` 0.15.x on all four targets?** The changelog never names them. *To answer:* a spike build plus one document per platform. (Rec 1)
- **Does a text-only LoRA work alongside an mmproj in llama.cpp, and through `llamadart`?** *To answer:* a half-day experiment, freezing the vision layers and converting with `convert_lora_to_gguf.py`. (Rec 5)
- **Does the "constraint tax" apply to document extraction, and does draft-then-constrain recover it at 2B?** *To answer:* an A/B on the D4 harness. (Rec 2)
- **How do NuExtract3, Qwen3.5 and Gemma 4 handle Romanian and German medical documents?** No card lists languages for extraction, and no Romanian OCR benchmark exists. *To answer:* the D4 language strata. (Rec 4)
- **How fast is image encoding per runtime on phones** (llama.cpp mtmd vs LiteRT-LM), and is the Android CPU encode regression (#27649, closed unfixed) inside `llamadart` 0.15's pinned build? *To answer:* device benchmarks, and a map from the `llamadart-native` v0.7.0 pin to a llama.cpp commit. (Rec 1)
- **Is `fhir_r4_validation` (R4B models) usable for R4 resources from Fasten, and do its binding checks work offline?** *To answer:* a package test. (Rec 2)
- ~~**Is there any partial-credit scoring for SNOMED/LOINC/RxNorm codes, and what gold-set size do we need?**~~ **Resolved 2026-10-22**;

## Source appendix

| [n] | claim/finding it supports | publisher | pub date | accessed | confidence |
|---|---|---|---|---|---|
| [1] | llamadart 0.15.6 (~2026-10-21, MIT): llama.cpp GGUF + LiteRT-LM .litertlm backends, multimodal projectors, LoRA, grammar, responseFormat JSON schema, tool calling; Metal / Vulkan (Android experimental) / CUDA, no OpenCL | [pub.dev llamadart](https://pub.dev/packages/llamadart) | 2026-10-21 | 2026-10-22 | high |
| [2] | llamadart 0.15.6 (2026-10-21): own Dart port of json_schema_to_grammar; unrepresentable or cyclic schemas throw instead of degrading; repetition-threshold check before generation; no llguidance | [GitHub leehack/llamadart CHANGELOG](https://github.com/leehack/llamadart/blob/HEAD/CHANGELOG.md) | 2026-10-21 | 2026-10-22 | high |
| [3] | llamadart LoRA API: setLoraSource/removeLoraSource/clearLoras, load-time loras, URL/hf:// sources with resumable download; llama.cpp backend stacks adapters, LiteRT-LM backend one text LoRA at load; mmproj interaction undocumented | [llamadart docs (leehack)](https://llamadart.leehack.com/docs/guides/lora-adapters) | 2026 (0.15.x) | 2026-10-22 | high |
| [4] | Independent iPhone 17 Pro Gemma 4 E2B test: decode LiteRT-LM 61.1, Cactus 50.0, MLX-Swift 49.1, Core AI 47.1, llama.cpp 38.8 tok/s; GSM8K 86% LiteRT-LM vs 76% llama.cpp Q4_K_M; sustained 10-min decode halves; no VLM image numbers yet | [GitHub john-rocky/apple-silicon-llm-bench (independent)](https://github.com/john-rocky/apple-silicon-llm-bench) | 2026-09 | 2026-10-22 | medium |
| [5] | llamadart LiteRT-LM backend: supportsGrammarConstraints false, strict output unsupported (open, P2); upstream LiteRT-LM C API v0.16/0.17 exports constraint setters | [GitHub leehack/llamadart #174](https://github.com/leehack/llamadart/issues/174) | 2026-05-28 (comments to 2026-09-21) | 2026-10-22 | high |
| [6] | Prompt API input limited to under 4000 tokens (an EN/KO-only validation note was seen only in a search snippet; unverified) | [Google for Developers (get started)](https://developers.google.com/ml-kit/genai/prompt/android/get-started) | 2026 | 2026-10-22 | medium (token limit) / unverified (languages) |
| [7] | VAREX: small-VLM non-compliance rises from 2–3% (flat schema) to 68–69% with $defs; inlining $defs lifts Qwen3-VL-2B 27.4→91.8% on that subset; 2B non-compliant on 56% of image inputs vs 17% text (same paper as the VAREX benchmark-design row) | [arXiv 2603.15118 (IBM Research)](https://arxiv.org/html/2603.15118) | 2026-04-09 (v2) | 2026-10-22 | high |
| [8] | Constraint tax at ≤3B: answer-only hard schema 100% valid but accuracy −8.7 pts (up to −20 per model, −43.5 on a tool call); 'reason free, constrain late' recovers most | [arXiv 2605.26128](https://arxiv.org/html/2605.26128) | 2026-05-20 | 2026-10-22 | high |
| [9] | StructureBench (11 on-device models 0.5–8B; Outlines, XGrammar, Guidance): constrained decoding enforces structure but does not reliably improve semantic accuracy and may degrade small models | [IJCAI 2026 proceedings](https://www.ijcai.org/proceedings/2026/267) | 2026 | 2026-10-22 | high |
| [10] | fhir_r4_validation 0.14.0 (2026-10-16): Dart validation of structure, cardinality, value-set bindings, FHIRPath invariants; models are R4B | [pub.dev fhir_r4_validation](https://pub.dev/packages/fhir_r4_validation) | 2026-10-16 | 2026-10-22 | high |
| [11] | Independent PureDocBench: Qwen3.5-2B 62.46 vs Qwen3-VL-2B 62.09 average (clean 66.24 vs 66.37; real photos 55.92 vs 54.09) — near tie, disputing vendor's ~15-pt OmniDocBench gap | [arXiv 2605.07492 (PureDocBench)](https://arxiv.org/html/2605.07492v2) | 2026-09-27 (v2) | 2026-10-22 | medium |
| [12] | MedGemma 1.5 4B card (vendor, mostly internal sets): EHR Dataset 4 macro F1 25→64 vs MedGemma 1; EHR2 78→91; EHR3 50→71; public Mendeley PNG→JSON 85→85; Gemma 3 4B base 83–84 on EHR2/Mendeley; HAI-DEF terms | [Hugging Face google/medgemma-1.5-4b-it](https://huggingface.co/google/medgemma-1.5-4b-it) | 2026-01-13 | 2026-10-22 | high (vendor-reported) |
| [13] | NuExtract3: Qwen3.5-4B fine-tune for document extraction, Apache-2.0; vendor benchmark 0.651 vs Qwen3.5-4B 0.417 (27 vs 229 failed outputs), Gemma 4 E4B 0.538; ExtractBench 82.35; languages 'multilingual' only | [Hugging Face numind/NuExtract3](https://huggingface.co/numind/NuExtract3) | 2026-05 | 2026-10-22 | medium (vendor-reported) |
| [14] | RAPTOR+: Qwen3-VL 2B/4B/8B fine-tuned on 176 synthetic clinical forms; 2B reading accuracy 62.3→88.3%, strict safety 0→21%; 8B 96.1% / 60.6% | [arXiv 2605.25956](https://arxiv.org/html/2605.25956) | 2026-06-03 (v2) | 2026-10-22 | high |
| [15] | LoRA r16/α32 on Qwen2.5-VL-3B/7B, ~3K synthetic checks, 6–14 A100-80GB GPU-hours; in-distribution F1 0.98, out-of-distribution 3B falls to 0.593 | [arXiv 2609.15706](https://arxiv.org/html/2609.15706) | 2026-09-19 (v2) | 2026-10-22 | high |
| [16] | llama-mtmd-cli accepts both --lora and --mmproj flags (no proof they work together) | [Debian manpages (llama.cpp-tools-extra)](https://manpages.debian.org/unstable/llama.cpp-tools-extra/llama-mtmd-cli.1.en.html) | rolling | 2026-10-22 | medium |
| [17] | macOS 27.0 SDK marks SystemLanguageModel.Adapter deprecated 26.4, obsoleted 27.0; custom adapters closed as not planned | [GitHub Arthur-Ficial/apfel #362 (independent)](https://github.com/Arthur-Ficial/apfel/issues/362) | 2026-10-05 | 2026-10-22 | high |
| [18] | MedRepBench: structured-field extraction from photographed/scanned medical reports with its own schema, not FHIR — closest public benchmark | [arXiv 2508.16674](https://arxiv.org/pdf/2508.16674) | 2025-08 | 2026-10-22 | medium |
| [19] | Qwen3.5 small dense (0.8B/2B/4B/9B) released 2026-03-02; no Qwen model ≤4B since May 2026 (Qwen3.6/3.8 are 27B+) | [GitHub QwenLM](https://github.com/QwenLM/Qwen3.8) | 2026-08 | 2026-10-22 | high |
| [20] | Gemma 4 E2B: 2.3B effective / 5.1B total params, Apache-2.0; GGUF Q4_K_M 3.11 GB before mmproj; vendor OmniDocBench edit distance 0.290 (E4B 0.181) | [Hugging Face unsloth/gemma-4-E2B-it-GGUF (Google card)](https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF) | 2026-04 | 2026-10-22 | high (sizes) / medium (scores) |
| [21] | MiniCPM-V 4.6: ~1B (SigLIP2 + Qwen3.5-0.8B), Apache-2.0, 2026-05-11, official GGUF; claims Qwen3.5-2B-level OCRBench with no numeric values | [Hugging Face openbmb/MiniCPM-V-4.6](https://huggingface.co/openbmb/MiniCPM-V-4.6) | 2026-05 | 2026-10-22 | high (facts) / low (perf) |
| [22] | PaddleOCR-VL-1.6 (0.9B, Apache-2.0, 2026-05-28): OmniDocBench v1.6 96.33, Real5 93.19 (vendor); parser, not extractor | [Hugging Face PaddlePaddle/PaddleOCR-VL-1.6](https://huggingface.co/PaddlePaddle/PaddleOCR-VL-1.6) | 2026-05-28 | 2026-10-22 | high (vendor-reported) |
| [23] | llama.cpp OCR support (2026-04-10): DeepSeek-OCR, dots.ocr, GLM-OCR, LightOnOCR, HunyuanOCR, PaddleOCR-VL; Gemma 4 E2B/E4B and Qwen3-VL-2B listed as general OCR-capable | [Hugging Face blog (ggml-org)](https://huggingface.co/blog/ggml-org/using-ocr-models-with-llama-cpp) | 2026-04-10 | 2026-10-22 | high |
| [24] | Qwen3.5-2B: Apache-2.0, image-text-to-text, released Feb 2026, vendor OCRBench/OmniDocBench scores | [Hugging Face Qwen/Qwen3.5-2B](https://huggingface.co/Qwen/Qwen3.5-2B) | 2026-02 | 2026-10-22 | high |
| [25] | Qwen3.5-4B: Apache-2.0, hybrid Gated DeltaNet, 201 languages; vendor OCRBench 85.0, OmniDocBench1.5 86.2, CC-OCR 76.7 | [Hugging Face Qwen/Qwen3.5-4B](https://huggingface.co/Qwen/Qwen3.5-4B) | 2026-02 | 2026-10-22 | medium (vendor-reported) |
| [26] | llama.cpp PR #19468 merged 2026-02-10: Qwen3.5 series support including vision (mmproj) | [GitHub ggml-org/llama.cpp #19468](https://github.com/ggml-org/llama.cpp/pull/19468) | 2026-02-10 | 2026-10-22 | high |
| [27] | Unsloth Qwen3.5-2B GGUF: Q4_K_M 1.28 GB + mmproj-F16 668 MB (~1.95 GB total) | [Hugging Face unsloth/Qwen3.5-2B-GGUF](https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/tree/main) | 2026-03 | 2026-10-22 | high |
| [28] | Unsloth Qwen3.5-4B GGUF: Q4_K_M 2.74 GB + mmproj-F16 672 MB (~3.4 GB total) | [Hugging Face unsloth/Qwen3.5-4B-GGUF](https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/tree/main) | 2026-03 | 2026-10-22 | high |
| [29] | Qwen3.5-2B on Android Adreno 740 Vulkan produced gibberish / slower than CPU; closed stale 2026-04-30 without fix | [GitHub ggml-org/llama.cpp #20603](https://github.com/ggml-org/llama.cpp/issues/20603) | 2026-03-15 | 2026-10-22 | high |
| [30] | VAREX: 1,777 synthetic template documents, four modalities, Hungarian array matching, doc-level bootstrap CIs; <4B models lose 45–65 pp to schema echo, 2B fine-tune +81 pp (same paper as the $defs row; cited separately for benchmark design) | [arXiv 2603.15118 (IBM Research, CVPRW 2026)](https://arxiv.org/html/2603.15118) | 2026-04-09 (v2) | 2026-10-22 | high |
| [31] | Community NuExtract3 GGUF: Q4_K_M 2.71 GB + mmproj BF16 676 MB; no official GGUF | [Hugging Face prithivMLmods/NuExtract3-GGUF](https://huggingface.co/prithivMLmods/NuExtract3-GGUF/tree/main) | 2026-08 | 2026-10-22 | medium |
| [32] | NuExtract 2.0: 2B on Qwen2-VL-2B (MIT), 4B on Qwen2.5-VL-3B (non-commercial), 8B (MIT); multimodal; superseded by NuExtract3 | [Hugging Face numind/NuExtract-2.0-2B](https://huggingface.co/numind/NuExtract-2.0-2B) | 2026-03 (approx.) | 2026-10-22 | high |
| [33] | HAI-DEF terms: LoRA/merge/distillation = Model Derivative; distribution requires flow-down of use restrictions, Agreement copy, Notice file, health regulatory authorisation when applicable; bans uses making Google a device manufacturer | [Google HAI-DEF Terms](https://developers.google.com/health-ai-developer-foundations/terms) | 2024-11-15 (last modified) | 2026-10-22 | high |
| [34] | Anecdote: MedGemma 1.5 Q8_0 quant fails to produce valid JSON on dense pages while BF16 works | [Google AI Developers Forum](https://discuss.ai.google.dev/t/177891) | 2026 | 2026-10-22 | low |
| [35] | Gemma 4 E2B .litertlm 2,583 MB; iPhone 17 Pro GPU prefill 2,878 tok/s, decode 56.5 tok/s, 1,450 MB; S26 Ultra GPU 3,808 / 52.1 tok/s; vision loaded on demand; text-only benchmarks | [Hugging Face litert-community (Google)](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm) | 2026-07 | 2026-10-22 | high (text) / vision perf not given |
| [36] | InternVL3.5-2B .litertlm ~1.61 GB, Apache-2.0, on-device vision (256 tokens/448px image); Android, iOS (Swift runtime), macOS, Linux/Windows; Metal second-image truncation bug | [Hugging Face litert-community/InternVL3_5-2B](https://huggingface.co/litert-community/InternVL3_5-2B) | 2026-08-31 | 2026-10-22 | high |
| [37] | LFM2.5-VL-1.6B: lfm1.0 licence, languages exclude Romanian, OCRBench v2 41.44 (vendor) | [Hugging Face LiquidAI/LFM2.5-VL-1.6B](https://huggingface.co/LiquidAI/LFM2.5-VL-1.6B) | 2026 | 2026-10-22 | high |
| [38] | llamadart changelog: 0.6.8 bundled llama.cpp b8480; breaking releases 0.7.1 (iOS 16.4/macOS 14), 0.10, 0.11, 0.14 (ABI); Qwen3.5 and Gemma 4 mmproj work; LiteRT-LM image input since 0.8.1; LiteRT-LM limits (one LoRA, no FST constraints on iOS, macOS arm64 only); Qwen3-VL and MedGemma never named | [pub.dev llamadart changelog](https://pub.dev/packages/llamadart/changelog) | 2026-10 | 2026-10-22 | high |
| [39] | Reported regression: llama.cpp mtmd vision encode ~2.7x slower on CPU-only Android (~30 s → ~81 s), Aug 2026 | [GitHub ggml-org/llama.cpp #27649](https://github.com/ggml-org/llama.cpp/issues/27649) | 2026-08 | 2026-10-22 | low-medium |
| [40] | llamadart repo: 78 stars, 1,235 commits, 124 open issues, single-maintainer style tracker; ~daily releases; recent Qwen3.5 vision bugs closed Oct 2026, LiteRT-LM Qwen3.5 GPU bug #672 open | [GitHub leehack/llamadart](https://github.com/leehack/llamadart) | 2026-10-21 (snapshot) | 2026-10-22 | medium |
| [41] | LiteRT-LM releases v0.16.0 Aug 11, v0.17.0 Sep 9, v0.18.0 Oct 6, v0.18.1 Oct 20 (2026); v0.15.0 adds an Apple Foundation framework adapter for Gemma 4 | [GitHub google-ai-edge/LiteRT-LM releases](https://github.com/google-ai-edge/LiteRT-LM/releases) | 2026-10-20 | 2026-10-22 | high |
| [42] | LiteRT-LM v0.18.x (Apache-2.0, Google): Android, iOS, web, macOS, Windows, Linux; GPU/NPU; vision and audio input; Flutter support 'Community' | [GitHub google-ai-edge/LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM) | 2026-10 | 2026-10-22 | high |
| [43] | LiteRT-LM: rank-16 LoRA loads on Gemma 4 E2B GPU bundle without error but leaves output unchanged (open, no maintainer reply) | [GitHub google-ai-edge/LiteRT-LM #3173](https://github.com/google-ai-edge/LiteRT-LM/issues/3173) | 2026-08-07 | 2026-10-22 | high |
| [44] | WWDC 2026 (2026-06-08): Foundation Models gains image input; Core AI framework announced | [MacRumors](https://www.macrumors.com/2026/06/08/apple-unveils-xcode-and-models-improvements/) | 2026-06-08 | 2026-10-22 | high (announcement) |
| [45] | apple/coreai-models requires macOS and iOS 27.0+ and Xcode 27 | [GitHub apple/coreai-models](https://github.com/apple/coreai-models) | 2026 (snapshot) | 2026-10-22 | high |
| [46] | Apple Foundation Models adapter toolkit 26.0.0 is the last release and does not work with OS 27+; adapters ~160 MB, one per system-model version, entitlement required, text-only data | [Apple Developer](https://developer.apple.com/apple-intelligence/foundation-models-adapter/) | 2026-10 (page current) | 2026-10-22 | high |
| [47] | ML Kit GenAI Prompt API (Gemini Nano): image+text input, alpha structured output, beta, no SLA | [Google for Developers](https://developers.google.com/ml-kit/genai/prompt/android) | 2026-07-15 | 2026-10-22 | high |
| [48] | flutter_edge_ai 2.5.1 (former flutter_gemma, MIT): LiteRT-LM, MediaPipe (maintenance-only), ONNX Runtime, llama.cpp via llamadart, OS models; no JSON constraint documented; LiteRT-LM and llama.cpp not qualified together on macOS | [pub.dev flutter_edge_ai](https://pub.dev/packages/flutter_edge_ai) | 2026-10-22 | 2026-10-22 | high |
| [49] | Cactus licence: free only below USD 2M revenue and funding (or non-commercial); otherwise commercial licence required; no Windows listed | [GitHub cactus-compute/cactus LICENSE](https://github.com/cactus-compute/cactus/blob/main/LICENSE) | 2025 | 2026-10-22 | high |
| [50] | ONNX Runtime GenAI: Phi vision models supported; Qwen3-VL only via qwen2_5_vl workaround (open request) | [GitHub microsoft/onnxruntime-genai #1989](https://github.com/microsoft/onnxruntime-genai/issues/1989) | 2026 | 2026-10-22 | low |
| [51] | 10,000 synthetic scanned care-transition records: ~97% accuracy on synthetic vs ~85% on real documents | [Stud Health Technol Inform (IOS Press)](https://journals.sagepub.com/doi/10.3233/SHTI251392) | 2025 | 2026-10-22 | medium |
| [52] | Synthea: Apache-2.0, exports FHIR R4 covering conditions, allergies, medications, immunizations, observations, labs, encounters; US (Massachusetts) demographics by default | [GitHub synthetichealth/synthea (MITRE)](https://github.com/synthetichealth/synthea) | 2025 | 2026-10-22 | high |
| [53] | Only 7 of 16 Synthea FHIR resource types matched German MII core-dataset profiles; conversion needed | [GMDS 2024 (GMS)](https://www.egms.de/static/en/meetings/gmds2024/24gmds150.shtml) | 2024 | 2026-10-22 | medium |
| [54] | Staged JSON-schema validity + grounding rewards proposed for GRPO (open, unmerged PR) | [GitHub huggingface/open-r1 #722](https://github.com/huggingface/open-r1/pull/722) | 2025 | 2026-10-22 | low |
| [55] | TRL v1.16.0 SFTTrainer supports VLM training with PEFT LoRA/QLoRA; set max_length=None to avoid truncating image tokens | [Hugging Face TRL docs](https://huggingface.co/docs/trl/sft_trainer) | 2026 (v1.16.0) | 2026-10-22 | high |
| [56] | Unsloth Qwen3.5: vision fine-tuning 0.8B–122B; bf16 LoRA ~5 GB VRAM at 2B, ~10 GB at 4B; advises against 4-bit QLoRA; GGUF export via save_pretrained_gguf, no mmproj mention | [Unsloth docs](https://unsloth.ai/docs/models/qwen3.5/fine-tune) | undated (assets 2026-04) | 2026-10-22 | high |
| [57] | LLaMA-Factory lists Qwen3-VL 2B/4B, Qwen3.5, Gemma 3/3n, MiniCPM-V 4.5/4.6; VRAM table for LoRA/QLoRA | [GitHub hiyouga/LLaMA-Factory](https://github.com/hiyouga/LLaMA-Factory) | README (2026-10) | 2026-10-22 | medium |
| [58] | MLX-VLM supports LoRA/QLoRA/DoRA and GRPO for VLMs on Apple Silicon | [GitHub Blaizzy/mlx-vlm](https://github.com/Blaizzy/mlx-vlm) | README (2026-10) | 2026-10-22 | medium |
| [59] | MedGemma 1.5 4B (updated 2026-01-13): document understanding incl. lab-report structured extraction; official LoRA and RL notebooks; decoder-only or decoder+encoder tuning | [Google Health AI Developer Foundations](https://developers.google.com/health-ai-developer-foundations/medgemma) | 2026-01-13 | 2026-10-22 | high |
| [60] | llama-server: multiple --lora adapters, scaling, global and per-request hot-swap; README silent on LoRA with --mmproj | [ggml-org/llama.cpp tools/server README](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) | master @ 2026-10 | 2026-10-22 | high |
| [61] | Merged LoRA + re-converted Qwen2.5-VL-32B with --mmproj produced only '@' tokens; closed stale without root cause | [GitHub ggml-org/llama.cpp #15870](https://github.com/ggml-org/llama.cpp/issues/15870) | 2025-09-08 (older) | 2026-10-22 | medium |
| [62] | Unsloth FastVisionModel trains vision, language, attention and MLP layers by default (toggles to freeze vision); no mmproj export documented | [Unsloth docs](https://unsloth.ai/docs/basics/vision-fine-tuning) | undated (current 2026-10) | 2026-10-22 | high |
| [63] | Gemma 4 released under Apache 2.0, replacing the Gemma Terms of Use | [Google Open Source Blog](https://opensource.googleblog.com/2026/03/gemma-4-expanding-the-gemmaverse-with-apache-20.html) | 2026-03 | 2026-10-22 | medium |
| [64] | llama.cpp JSON-Schema→GBNF converter is a subset that skips unsupported features silently (nested $ref, anyOf+properties, number bounds, prefixItems); schema not injected into prompt; x? x? repetition slow | [ggml-org/llama.cpp grammars/README.md](https://github.com/ggml-org/llama.cpp/blob/master/grammars/README.md) | master @ 2026-10 | 2026-10-22 | high |
| [65] | Large $ref/$defs schemas exceeded repetition threshold and the constraint was dropped silently; closed as completed 2026-04-11 (fix commit unidentified) | [GitHub ggml-org/llama.cpp #21228](https://github.com/ggml-org/llama.cpp/issues/21228) | 2026-03-31 | 2026-10-22 | medium |
| [66] | Grammar not enforced with enable_thinking + response_format; closed 2026-03-10; maintainers recommend response_format over raw grammar with reasoning | [GitHub ggml-org/llama.cpp #20345 / #22537](https://github.com/ggml-org/llama.cpp/issues/20345) | 2026-03-10 | 2026-10-22 | high |
| [67] | Unbounded schema nesting crash (CVE-2026-52130) closed not_planned 2026-09-30; nesting-cap PR #30242 still open; minItems OOM #29462 open | [GitHub ggml-org/llama.cpp #29690](https://github.com/ggml-org/llama.cpp/issues/29690) | 2026-09-30 | 2026-10-22 | high (status) |
| [68] | Open: optional property before a required one is silently dropped because the object rule enforces required-first order | [GitHub ggml-org/llama.cpp #30321](https://github.com/ggml-org/llama.cpp/issues/30321) | 2026-10-11 | 2026-10-22 | high |
| [69] | llama.cpp optional llguidance backend (LLAMA_LLGUIDANCE=ON, Rust), errors on unsupported keywords, ~50 µs/token mask, keeps property order | [ggml-org/llama.cpp docs/llguidance.md](https://github.com/ggml-org/llama.cpp/blob/master/docs/llguidance.md) | master @ 2026-10 | 2026-10-22 | high (behaviour) / medium (timing) |
| [70] | 0.6–4B models: constrained decoding raised validity to 100% and content accuracy (Llama-3.2-3B 0.777→0.991); fixes form, not semantics | [arXiv 2609.23742](https://arxiv.org/html/2609.23742v1) | 2026-09-20 | 2026-10-22 | medium |
| [71] | JSONSchemaBench: constrained decoding slightly raised accuracy on Llama-3.1-8B (GSM8K 80.1→82.4% llama.cpp, 83.8% Guidance); llama.cpp grammar ~2x per-token time; coverage gaps | [arXiv 2501.10868 (ICML 2025)](https://arxiv.org/html/2501.10868v2) | 2025-02 (older) | 2026-10-22 | high (for those versions) |
| [72] | Format Tax: most loss comes from format-requesting instructions rather than the decoder mask; separating reasoning from formatting recovers accuracy | [arXiv 2604.03616](https://arxiv.org/abs/2604.03616) | 2026-04 | 2026-10-22 | medium |
| [73] | Draft-Conditioned Constrained Decoding: free draft then constrained pass, up to +24 pts at 1–1.5B on reasoning tasks; two decoding passes | [arXiv 2603.03305](https://arxiv.org/html/2603.03305) | 2026-06-27 (v2) | 2026-10-22 | high |
| [74] | CFG from FHIR R5 JSON Schemas with relaxed key order: 76.5% valid vs 41.2% JSON-schema-guided vs 17.6% unguided on 17 cases, Llama 3.3 70B; paper CC BY-NC 4.0 | [MIE 2026, Stud Health Technol Inform 336 (IOS Press)](https://ebooks.iospress.nl/doi/10.3233/SHTI260725) | 2026 | 2026-10-22 | high |
| [75] | CFG4FHIR repo: no licence file; valid-but-wrong enums and repetition loops observed even with CFG | [GitHub j-frei/CFG4FHIR](https://github.com/j-frei/CFG4FHIR) | 2026-08-21 | 2026-10-22 | high |
| [76] | Infherno rejected a full FHIR grammar as too costly, generating via fhir.resources instead | [arXiv 2507.12261](https://arxiv.org/pdf/2507.12261) | 2025-07 | 2026-10-22 | medium |
| [77] | Apple Foundation Models (2026): on-device text+image understanding, @Generable guided generation, custom LanguageModel provider for Core AI-exported models | [Apple Developer documentation](https://developer.apple.com/documentation/foundationmodels) | 2026 (WWDC26) | 2026-10-22 | high |
| [78] | LiteRT-LM C++ constrained decoding via LLGuidance provider (regex, JSON Schema, Lark) | [google-ai-edge/LiteRT-LM docs](https://github.com/google-ai-edge/LiteRT-LM/blob/main/docs/api/cpp/constrained-decoding.md) | 2026 | 2026-10-22 | medium |
| [79] | LiteRT-LM open bugs: EOS legal inside JSON strings (#3721); no spaces in constrained output with SentencePiece (#3510) | [GitHub google-ai-edge/LiteRT-LM #3721](https://github.com/google-ai-edge/LiteRT-LM/issues/3721) | 2026 | 2026-10-22 | medium |
| [80] | LlamaIndex ExtractBench: Hungarian record alignment, cell-bag micro-F1 per document, absent key = null, exact comparators, no LLM judge; VLM long-list truncation | [arXiv 2607.29677 (LlamaIndex)](https://arxiv.org/html/2607.29677) | 2026-08 (v2) | 2026-10-22 | high |
| [81] | ExtractBench evaluator code Apache-2.0, active (last push 2026-10-21) | [GitHub run-llama/ExtractBench](https://github.com/run-llama/ExtractBench) | 2026-10-21 | 2026-10-22 | high |
| [82] | Contextual AI ExtractBench: per-field evaluation_config comparators, present/null/MISSING states, invalid JSON kept in denominator (validity 37–51%), MIT licence | [arXiv 2602.12247 (Contextual AI)](https://arxiv.org/html/2602.12247) | 2026-02 | 2026-10-22 | high |
| [83] | FHIR Validity Rate via HL7 validator (errors only), Terminology Grounding Accuracy; headline numbers partly placeholders per authors | [arXiv 2601.05847v2](https://arxiv.org/html/2601.05847v2) | 2026-05-22 | 2026-10-22 | high (method) / low (numbers) |
| [84] | ucum-lhc: UCUM validation/conversion/commensurability API, active; custom licence unreviewed | [GitHub lhncbc/ucum-lhc (NLM)](https://github.com/lhncbc/ucum-lhc) | 2026-10-19 | 2026-10-22 | high (API) / low (licence) |
| [85] | Hierarchy-aware partial credit (prefix-n, ancestry overlap) published for ICD coding only | [arXiv 2510.07629 (EMNLP 2025 Industry)](https://arxiv.org/html/2510.07629) | 2025-10 | 2026-10-22 | medium |
| [86] | VAREX code Apache-2.0; dataset licence only stated as 'permissive' | [GitHub udibarzi/varex-bench](https://github.com/udibarzi/varex-bench) | 2026-05-04 | 2026-10-22 | high (code) / low (data licence) |
| [87] | FHIR Workbench Note2FHIR F1 0.038–0.363 across models (F1 definition not retrieved) | [JMIR 2025 e73540](https://www.jmir.org/2025/1/e73540) | 2025 | 2026-10-22 | low |
| [88] | CIRCA: deterministic FHIR R4 mapper for 10,011 intents; models 18–35% on all closed fields; MIMIC layers need credentialed access | [arXiv 2609.29479](https://arxiv.org/abs/2609.29479) | 2026-08-24 | 2026-10-22 | high |
| [89] | flexpa/llm-fhir-eval: promptfoo with FHIRPath/validator assertions; no LICENSE file, last push 2026-02-04 | [GitHub flexpa/llm-fhir-eval](https://github.com/flexpa/llm-fhir-eval) | 2026-02-04 | 2026-10-22 | high |
| [90] | Infherno: text-only notes→FHIR agent, no LICENSE file, no metric in README | [GitHub j-frei/Infherno (EACL 2026 demo)](https://github.com/j-frei/Infherno) | 2026-04-02 | 2026-10-22 | high |
| [91] | Healthcare LLM-as-judge scoping review (49 studies): 73.5% no risk-of-bias testing, 26.5% no expert validators; shared-blind-spot risk | [arXiv 2604.25933](https://arxiv.org/abs/2604.25933) | 2026-04-03 | 2026-10-22 | high |
| [92] | Clustered vs hierarchical bootstrap for nested text data | [arXiv 2606.26422](https://arxiv.org/pdf/2606.26422) | 2026-06 | 2026-10-22 | medium |
| [93] | Underpowered NLP comparisons are common; simulation-based power analysis, no closed-form test-set size | [arXiv 2010.06595 (EMNLP 2020)](https://arxiv.org/abs/2010.06595) | 2020-10 (older) | 2026-10-22 | high |
| [94] | llama-bench measures text pp/tg throughput only; no image encode, TTFT or RAM | [ggml-org/llama.cpp tools/llama-bench README](https://github.com/ggml-org/llama.cpp/blob/master/tools/llama-bench/README.md) | master @ 2026-10-22 | 2026-10-22 | high |
| [95] | Mobile inference thermal methodology: consecutive runs trigger down-clocking; control starting temperature | [arXiv 2410.03613](https://arxiv.org/pdf/2410.03613) | 2024-10 (older) | 2026-10-22 | medium |
| [96] | Galaxy S25 Ultra llama.cpp study: 0.5–9B ran, only ≤~3B gave usable interactivity | [arXiv 2603.26603](https://arxiv.org/abs/2603.26603) | 2026-03 | 2026-10-22 | medium |

## Staleness map

Computed with `recon_kit.py staleness` using the technical pack's freshness bars, in months: version/compatibility and failure 1, performance and capability 3 (AI-adjacent), licence 6, dataset 12, pattern 24. Claims about current status (an issue being open, what a licence says, which files exist) are dated by when I observed them, 2026-10-22, not by when the page was first posted.

**7 of 23 load-bearing claims are already past their freshness bar.** All of them are vendor or paper performance numbers from January–July 2026 that nobody has re-measured since. That is the thin-evidence problem the executive summary names: the D4 benchmark replaces them. The earliest re-check date is **2026-04-01** (MedGemma 1.5's vendor scores, already overdue). The fast-moving version and status claims (`llamadart`, llama.cpp issues, LiteRT-LM) are due by **2026-11-22**. As a selection report, the whole document should be refreshed before anyone acts on it after **2027-04-22**.

| Re-check by | Stale today | Class | Claim |
|---|---|---|---|
| 2026-04-01 | yes | performance | [12] MedGemma 1.5 4B lab-report PDF→JSON macro F1 25→64 (internal); public Mendeley PNG 85=85 (vendor only) |
| 2026-05-01 | yes | failure | [7] Small VLM schema non-compliance 2–3% flat vs 68–69% with $defs; inlining lifts Qwen3-VL-2B 27.4→91.8% |
| 2026-06-01 | yes | performance | [24] Qwen3.5-2B vendor doc lead (OmniDocBench 80.9 vs 65.9) over Qwen3-VL-2B; independent PureDocBench shows near tie |
| 2026-08-01 | yes | performance | [13] NuExtract3 0.651 vs Qwen3.5-4B 0.417 on NuMind extraction benchmark (vendor) |
| 2026-08-01 | yes | performance | [8] Hard schema decoding at ≤3B: 100% valid, accuracy loss; reason-free-constrain-late recovers (direction confirmed by StructureBench IJCAI 2026) |
| 2026-09-01 | yes | performance | [14] RAPTOR+ Qwen3-VL-2B fine-tune 62.3→88.3% reading accuracy on 176 forms |
| 2026-10-01 | yes | performance | [35] Gemma 4 E2B .litertlm 2.58 GB, iPhone 17 Pro GPU decode 56.5 tok/s (consistent with independent 61.1) |
| 2026-11-01 | no | version/compatibility | [46] Apple FM adapter toolkit 26.0.0 last release; SDK obsoletes Adapter at 27.0 (apfel #362) |
| 2026-11-01 | no | version/compatibility | [2] llamadart uses own Dart schema→GBNF port; unsupported schemas throw; no llguidance |
| 2026-11-01 | no | failure | [68] llama.cpp: optional-before-required property silently dropped (open) |
| 2026-11-01 | no | version/compatibility | [10] fhir_r4_validation 0.14.0 validates on-device in Dart; models are R4B |
| 2026-11-22 | no | version/compatibility | [31] Community NuExtract3 Q4_K_M 2.71 GB + 676 MB mmproj, no official GGUF (status observed 2026-10-22) |
| 2026-11-22 | no | version/compatibility | [26] Qwen3.5 vision in mainline llama.cpp since 2026-02-10; llamadart changelog wires Qwen3.5 mmproj (status observed 2026-10-22) |
| 2026-11-22 | no | version/compatibility | [5] llamadart LiteRT-LM backend has no grammar/JSON constraints (open) (status observed 2026-10-22) |
| 2026-11-22 | no | failure | [43] LiteRT-LM LoRA on Gemma 4 E2B GPU is a silent no-op (open) (status observed 2026-10-22) |
| 2026-11-22 | no | version/compatibility | [27] Qwen3.5-2B Q4_K_M + mmproj ≈ 1.95 GB vs ~1.5 GB Lite budget (status observed 2026-10-22) |
| 2026-11-22 | no | failure | [29] Qwen3.5-2B gibberish on Adreno Vulkan, closed stale unfixed (status observed 2026-10-22) |
| 2026-12-01 | no | performance | [11] Independent: Qwen3.5-2B 62.46 vs Qwen3-VL-2B 62.09 on PureDocBench |
| 2026-12-01 | no | performance | [15] Templated synthetic LoRA: in-distribution F1 0.98, OOD 0.59 (synthetic-to-real gap corroborated by SHTI care-transition study) |
| 2027-01-01 | no | capability | [16] No end-to-end evidence of text LoRA + mmproj working in llama.cpp |
| 2027-04-22 | no | licence | [33] MedGemma LoRA/merge is a Model Derivative; a model trained on MedGemma outputs to perform like it is too (status observed 2026-10-22) |
| 2027-10-01 | no | dataset | [18] No public dataset pairs medical document images with FHIR R4 (absence confirmed by two researchers + verifier) |
| 2028-08-01 | no | pattern | [80] Hungarian record matching + per-document micro-F1 is the 2026 extraction scoring pattern (also VAREX) |
