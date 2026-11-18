# CSASS: code and run-level results

**Constraint-Sensitive Adaptive Surrogate Selection for Expensive Constrained Multi-Objective Structural Optimization**

This release accompanies the manuscript snapshot dated **18 November 2026**. It contains the implementation, configurations, saved final solution sets, run-level indicators, process records, and verification tools for the benchmark study. The suggested release tag is `v1.0.0`. A tag/repository URL is not claimed until the authors actually publish it.

## Start with the saved results

No optimization is needed to check the reported benchmark results. From this repository's root:

```bash
python scripts/verify_tables.py --root .
python scripts/verify_process.py --root .
python -m pip install -r requirements.txt
python scripts/verify_saved_metrics.py --root . --output verification_recomputed/saved_metrics
python scripts/verify_release_hashes.py --root .
```

The first two checks use the Python standard library. Recomputing IGD and HV from the final objective arrays requires NumPy. These commands create verification reports under `verification_recomputed/`; they do not fit models, evaluate benchmark functions, alter frozen results, or start optimization.

`scripts/verify_saved_metrics.py` checks all **15,120 distinct saved final sets**: 12,960 main-comparison runs and 2,160 ablation controls. The 540 adaptive ablation records refer to the same main-comparison records and are not counted twice. The absolute/relative comparison tolerances (1e-10/1e-9) allow floating-point and CSV-rounding differences; no recorded value is adjusted.

## Data and manuscript mapping

| Evidence | Records | Main files |
|---|---:|---|
| Main benchmark comparison, Tables 2–5 | 12,960; 432 groups of 30 | `data/Main/main_runs.csv`, `data/Main/runs/` |
| Ablation, Tables 6–8 | 2,700; 90 groups of 30 | `data/Ablation/ablation_runs.csv`, `data/Ablation/shared_adaptive_runs.csv` |
| Adaptive model usage, Figure 3 | 21,600 run/stage records | `data/Process/Latest18/adaptive_model_selection.csv` |
| Prediction-error analysis, Figures 4–5 | 72,000 run/stage/response records | `data/Process/Latest18/stage_rmse_all18.csv` |
| CF7 sensitivity, Figure 6 | 270; nine settings of 30 | `data/Sensitivity_CF7/all_runs.csv` |
| Controlled runtime, Table 9 | 480; 16 groups of 30 | `data/Runtime/run_results_full_precision.csv` |

See [`docs/TABLE_FIGURE_MAPPING.md`](docs/TABLE_FIGURE_MAPPING.md) for individual tables/figures and [`docs/DATA_PROVENANCE.md`](docs/DATA_PROVENANCE.md) for cohort identity and coverage. The main and runtime folders deliberately contain some identical run IDs in **different cohorts**. Runtime observations do not replace the main IGD/HV runs.

The current Table 2–8 TeX fragments and the controlled-runtime Table 9 are in `paper_tables/`. They are included to make numerical and significance-symbol comparisons checkable, rather than requiring access to a particular PDF. `verification/` contains the completed independent checks for this release.

### Feasible-run counts

`data/Feasibility/main_feasible_counts_432.csv` and `ablation_feasible_counts_90.csv` report the number of runs with at least one feasible final point, out of 30. The per-run `FeasibleND` column gives the number of final feasible nondominated points. Supplementary tables S1–S5 and the CF8 initialization trace are in `data/Supplementary/`.

- `FeasibleND > 0` means the run has a nonempty feasible final set.
- `NoFeasibleRuns` is the number with an empty feasible final set.
- `ZeroHVRuns` also includes feasible sets that contribute no positive volume inside the chosen reference region.
- `FeasibleButZeroHVRuns` identifies this latter case explicitly.

Consequently, zero HV is **not** used as a substitute for counting feasible runs. A main-table `N/A` denotes a non-finite all-30 IGD summary; it does not mean that all 30 runs failed. All 30 observations remain in the rank-sum comparison, with infinite IGD tied as worst. Feasibility-dominated comparisons should be interpreted using the accompanying counts.

## Frozen algorithm and evaluation settings

MATLAB R2023b on 64-bit Windows was used for the reported algorithm experiments (Intel Core i7-9700K, 3.60 GHz; 64 GB RAM). The controlled Table 9 measurements use sequential trials and one computational thread. Benchmark batches may use six process workers with one computational thread per trial; batch concurrency must not be treated as the Table 9 timing protocol.

- CF1–CF10 and LIRCMOP1–LIRCMOP14; decision dimensions 10, 20, 50; 30 seeds per setting.
- Nominal population size 100 and 500 true evaluations; three-objective A-NSGA-III/C-TAEA use 91 reference directions/initial individuals as documented in the study protocol.
- CSASS: `Pmax=20`, `K=10`, multiquadric RBF with shape parameter 1; objective and total-violation model choices are updated separately. Undefined or tied R² retains the preceding model.
- The 21 CSASS core source files are byte-identical across the benchmark, ablation, and controlled-runtime packages. The source hash report is in `verification/core_comparison.json`.
- The five competitors use the retained study protocol implementations. `docs/DATA_PROVENANCE.md` identifies initialization and budget handling; do not silently replace them with different installations or CDP variants.

**Use the study launchers, not the core function's default options.** The low-level options retain a quadratic/2,000-reference-point default from the original software scaffold. The published launchers explicitly select the multiquadric kernel, and the reported indicators are calculated from the saved final sets with the supplied PF10000 references. Calling `csass_run_v2` without those overrides is not the published experiment configuration.

The directory/ID token `V2` is retained as an identifier in the frozen source and data. It does not select a different implementation within the current benchmark/ablation comparison.

## Run the MATLAB experiments

MATLAB itself and its toolboxes are not included. Use a fresh MATLAB session, set the current folder to the repository root, and run:

```matlab
MAIN_CSASS_PUBLIC                 % help only; no optimization
MAIN_CSASS_PUBLIC('benchmark','preflight')
MAIN_CSASS_PUBLIC('ablation10','preflight')
MAIN_CSASS_PUBLIC('ablation2050','preflight')
MAIN_CSASS_PUBLIC('runtime','preflight')
MAIN_CSASS_PUBLIC('sensitivity','plan')
```

Only an explicit `run` requests optimization:

```matlab
MAIN_CSASS_PUBLIC('benchmark','run')
MAIN_CSASS_PUBLIC('ablation10','run')
MAIN_CSASS_PUBLIC('ablation2050','run')
MAIN_CSASS_PUBLIC('runtime','run')
MAIN_CSASS_PUBLIC('sensitivity','run')
MAIN_CSASS_PUBLIC('opponents_missing8','run')
MAIN_CSASS_PUBLIC('opponents_full','run')
```

Run one controller at a time. Keep published `data/` unchanged. The retained launchers write new outputs in their own `code/<package>/outputs/` folders; the new sensitivity wrapper writes to `reproduced/sensitivity_cf7/`. Completed records are resumed and interrupted/failed records are retained rather than silently replaced. The main CSASS launcher includes verified baseline caches used by the published campaign; its manifest distinguishes reused records from newly executed ones.

The `sensitivity` wrapper is a release convenience wrapper around the unchanged core, not a recovered historical controller. It explicitly defines the nine CF7 D=10 settings and can generate a fresh 270-run reproduction. The published cohort instead reuses the default 30 runs from the main comparison. The frozen original 270 records are included regardless of whether a reader reruns the wrapper.

The historical `MAIN_CSASS_ALL` retained under the competitor-provenance package can also execute an obsolete CSASS branch. It is **not** the public CSASS entry point. The root dispatcher intentionally does not route current CSASS through it. See `docs/RUNNING.md` for the current opponent-only reproduction entry point and toolbox requirements.

## Indicator definitions used by the scripts

IGD is computed in the original objective units using the supplied benchmark reference fronts generated by `GetOptimum(10000)`. The request is 10,000 points; the actual number is problem-dependent and is recorded in `verification/reference_front_inventory.csv`. The supplied fronts are authoritative for this release.

HV uses exact two- or three-objective union volume after normalization by each reference front's objective minima/ranges. It uses the common point `(1.1,...,1.1)`, does not clip objectives, and is not divided by box volume. Empty feasible sets have IGD=Inf and HV=0. The ablation sensitivity calculation also reports r=3 and r=20 on the same sets.

Tables use sample standard deviations and all 30 independent observations. Main comparisons use two-sided Wilcoxon rank-sum tests with tie and continuity correction, alpha=0.05. Ablation comparisons additionally apply Holm correction across the four controls within each setting/metric. Symbols `+`, `-`, `=` refer to CSASS being significantly better, worse, or not significantly different. Identical constant samples receive `=`.

## Large evaluation/process logs

Download **all** `CSASS_logs_*.zip` assets from the same Release if detailed evaluation or training traces are needed. Extract each ZIP into the repository root; the archives contain `data/...` relative paths. Final sets and the main verification CSVs are already in the repository package, so these large logs are optional for recomputing Tables 2–9 and the supplied process aggregates.

Not every main run retains a full per-evaluation ledger. `verification/main_run_artifact_coverage_12960.csv` states the actual coverage. All 12,960 main final sets are available. For six CF2 D=10 runs, saved-history reconstruction supplies the process traces separately under `data/Process/CF2_exact_ledger_replay`; their provenance is retained, and the reconstruction is not presented as a new optimization run.

## Scope of the engineering case

The release verifies the benchmark experiments and the controlled runtime comparison. The retained engineering Tables 13–15 do not have a recovered complete run-level cohort, engineering IGD reference set, selected-point rule, or executable finite-element project. They are not represented as reproducible outputs of this benchmark package. See `docs/ENGINEERING_SCOPE.md` for the specific outstanding sources.

## Publication, attribution and licenses

Publish this repository at a fixed tag and attach the accompanying log ZIPs plus `RELEASE_ASSETS_SHA256.csv` to that same GitHub Release. The paper and response should link to that Release, not only to an unversioned repository homepage. No files have been uploaded by the packaging process.

See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and `licenses/`. Third-party source headers and conditions remain in force; no blanket replacement license is applied. MATLAB is proprietary software and must be obtained separately. The authors may select an appropriate license for their own original code/data before publication; this package does not silently grant one for third-party components.
