# Manuscript-to-data mapping (2026-11-18)

This mapping refers to the saved manuscript `CSASS_R4_20261118/LaTeX/CSASS_revised.tex`. Table and figure numbers were read from its compiled `.aux` file. It does not claim that historical engineering raw data have been recovered.

| Item | Content | Frozen source / computation | Release status |
| --- | --- | --- | --- |
| Table 1 | Experimental settings | Current Section 3 implementation, runner configuration, population/FE manifest | Source/configuration audit; this is a settings table, not a run summary |
| Tables 2–3 | CF and LIR-CMOP IGD | `data/Main/main_runs.csv`, 12,960 records, 432 algorithm/problem/dimension groups; `IGD10000`; all 30 runs retained | Independently recomputed values and significance symbols match all current cells |
| Tables 4–5 | CF and LIR-CMOP HV | Same main records and final sets; `HV1p1`; reference-front normalization and common r=1.1 | Independently recomputed values and significance symbols match all current cells |
| Table 6 | IGD ablation | `data/Ablation/ablation_runs.csv`, 2,700 records, 90 groups; 540 adaptive records directly reference main CSASS final sets | All current cells match full-30 statistics and Holm-corrected comparisons |
| Table 7 | HV ablation | Same 2,700 records, `HVr1p1` | All current cells match |
| Table 8 | HV reference sensitivity | Same ablation records, `HVr1p1`, `HVr3`, `HVr20` | Recomputed better/worse/equal = 20/0/52, 26/2/44, 26/2/44; all-zero settings = 6,4,3 |
| Table 9 | Controlled runtime comparison | New 480-run runtime cohort, four problems at D=10, four surrogate-assisted algorithms, sequential execution and one compute thread; use the 2026-11-18 verified output, not historical runtime values | Independently recomputed all 16 current table entries and 12 comparison symbols from full-precision `complete.json` Row timers; keep this cohort separate from main optimization runs |
| Table 10 | Milling parameters | Reported engineering inputs in manuscript | Input values can be transcribed; not a recoverable run-level algorithm result |
| Table 11 | Original column natural frequencies | Reported finite-element outputs | Original FE project/raw output not recovered |
| Table 12 | Column design-variable ranges | Reported engineering model inputs | Parameters available; no current executable column evaluation model recovered |
| Table 13 | Column IGD | Historical aggregate values in manuscript | Run-level results, engineering reference front, and exact implementation link are unresolved; exclude from verified benchmark-data claims |
| Table 14 | Chosen column dimensions | Reported selected and rounded design | The run/point ID and selection criterion were not recovered |
| Table 15 | Column objective values | Reported initial and selected design FE results | Reported values available; no reproducible FE project or run lineage recovered |
| Figure 2 | CF2 D=10 feasible nondominated sets | `figures/Figure2_Figure6/data/` six selected final-objective CSVs and CF2 reference front; each algorithm's 15th run by ascending IGD, seed tie-break | Current figure displays all 58 points; no objective normalization or pooling |
| Figure 3 | Surrogate use by stage | `data/Process/Latest18/adaptive_model_selection.csv` (21,600 records) → `data/Process/ModelUsage/selection_40_stages.csv` (720 plotting rows) | All plotted fractions independently verified against `UsedObjectiveModel`/`UsedConstraintModel` |
| Figures 4–5 | Prediction RMSE | `data/Process/Latest18/stage_rmse_all18.csv` (72,000 run/stage/response records); four plotted cases selected in manuscript | All 560 plotted mean rows match latest 30-run stage records; stage means use mean of per-run RMSE |
| Figure 6 | CF7 D=10 sensitivity | `figures/Figure2_Figure6/data/CF7_all_runs.csv` and `CF7_group_summary.csv`; 270 records, nine settings | Default Pmax=20/K=10 is the same 30-record group in both panels and the main CSASS comparison |

## Feasible-run counts and additional review evidence

The count is the number of runs whose final feasible nondominated set contains at least one point (`FeasibleND > 0`). An HV value of zero alone does not imply that no feasible solution was found.

- `Table_S1_Provenance_432.csv`: origin of every current main algorithm/problem/dimension group.
- `Table_S2_Main_FeasibleRuns_72.csv`: 72 problem/dimension rows, one column per algorithm (432 counts).
- `Table_S3_Ablation_FeasibleRuns_90.csv`: counts for all 90 ablation groups.
- `Table_S4_CF8_D10_SharedInitial_30.csv`: per-seed shared-initial-sample evidence.
- `CF8_D10_InitialFinal_Trace_150.csv`: underlying 150 ablation runs for that check.
- `Table_S5_Violation_RMSE_EarlyLate_18.csv`: aggregated violation errors for all 18 adaptive settings.

These tables should be released with the run-level data. Their placement in the repository does not replace reporting the requested counts in the manuscript or supplementary material.

## Recalculation utilities

`verify_tables.py` requires only Python's standard library. It reads the main and ablation run CSVs and compares their recalculated values against seven copied TeX tables. It writes recalculated group statistics, feasible counts, ablation comparisons and a JSON verification report. No optimization is started. It validates aggregation of the saved indicators; a separate final-set verification is required to validate IGD/HV from raw objective arrays.

`verify_process.py` checks Figure 3 usage fractions, the four Figure 4/5 plot cases, and phase errors. Early/late errors are computed within each run as the square root of the average squared stage RMSE across stages 1–10/31–40, then averaged across runs. Every stage has ten newly evaluated points, so this is equivalent to pooling the 100 errors within each phase. It is not the arithmetic mean of ten stage RMSE values.

## Files that must not be substituted for the current data

1. The omitted archival `05_Data/Ablation/tables/ablation_statistics.csv` contains old conditional-finite-only IGD rows and associated labels. It is not the authoritative source of the current Table 6 significance marks. Recompute from `ablation_runs.csv` with the current full-30 policy.
2. `05_Data/CF7_Verification_NotUsedInFigure6` is an archival directory name. Its 270 verified records now underpin the replaced current Figure 6, so the public directory can be named `Sensitivity/CF7`; preserve its record provenance.
3. The archived `CF2_CurrentData_ReferenceOnly_NotInManuscript` description is obsolete for current Figure 2. Use the new 2026-11-18 FigureSources package, which explicitly records the current figure and full axes.
4. Runtime observations are a dedicated controlled cohort and must not silently replace the main IGD/HV or ablation baselines.
5. Engineering Tables 13–15 cannot be asserted to come from this benchmark implementation unless their missing source evidence is obtained.

## Independent verification completed

- Tables 2–7: 1,044 numerical/significance cells checked, zero mismatches.
- Table 8: all three reference-point summaries match.
- Table 9: all 16 full-precision-derived mean/SD entries and 12 significance marks match.
- Main/ablation overlap: 540 shared adaptive IDs, IGD values, r=1.1 HV values and final-set paths match.
- Figure 3: 720 fractions match 21,600 recorded model choices.
- Figures 4–5: 560 plotting rows match 72,000 available run-stage-response records.
- Early/late phase table: all 60 response-group aggregates match, covering 18 constraint-response settings.

This audit did not start any new optimization runs or change manuscript data.
