# MATLAB running guide

## Software

Use MATLAB R2023b, Windows 64-bit, and the bundled source paths. Do not add a different PlatEMO distribution ahead of them.

- Base MATLAB: current CSASS core and the serial sensitivity wrapper.
- Parallel Computing Toolbox: six-worker benchmark, D20/D50 ablation, Missing8 and full-opponent controllers.
- Statistics and Machine Learning Toolbox: competitor dependencies and MATLAB rank-sum calculations.
- Deep Learning Toolbox: HeEMOEA/PC-SAEA dependencies including newrb/newpnn/mapminmax/dist.
- LIBSVM Windows64 MEX files are retained with their copyright notice. They are not cross-platform binaries.

The D10 ablation controller is serial; the D20/D50 and main controllers use six process workers and one compute thread/trial. Runtime is serial and single-threaded and does not create a parallel pool.

## Entry points

Start in this repository's root in a fresh MATLAB session. `MAIN_CSASS_PUBLIC` with no arguments prints help only. For each action, `preflight` checks hashes/configuration/dependencies without starting optimization. Then use an explicit `run` only if you intend to perform a new experiment.

| Action | Frozen scientific scope | Fresh output |
|---|---|---|
| benchmark | Current CSASS, all 24 problems, D10/20/50, 30 seeds; 210 cached records + 1950 scheduled slots | code/CSASS_AllBenchmarks_MATLAB/outputs/V2_AllBenchmarks |
| ablation10 | Six problems, D10, five modes, 30 seeds; 360 cached + 540 scheduled slots | code/CSASS_Ablation_D10_MATLAB/outputs/V2_Ablation_D10 |
| ablation2050 | Six problems, D20/50, five modes, 30 seeds; 1800 slots | code/CSASS_Ablation_D20D50_MATLAB/outputs/Ablation_D20D50 |
| opponents_missing8 | CF2/3/4/6, LIRCMOP5/6/9/10, D10/20/50, five opponents, 30 seeds | code/FrozenOpponents_Missing8_MATLAB/outputs/Missing8_Opponents |
| opponents_full | All 24 problems, D10/20/50, five opponents, 30 seeds; 10800 fresh slots, no CSASS branch | reproduced/opponents_full |
| sensitivity | CF7 D10, Pmax=20/40/60/80/100 at K10, K=5/15/20/30 at Pmax20; 270 fresh slots | reproduced/sensitivity_cf7 |
| runtime | CF1/CF7/LIRCMOP1/LIRCMOP7 D10, four surrogate-assisted algorithms, 30 seeds; 480 slots | code/Runtime_Table9/outputs/Runtime_Table9_480 |

Examples:

```matlab
MAIN_CSASS_PUBLIC('benchmark','preflight')
MAIN_CSASS_PUBLIC('benchmark','run')
MAIN_CSASS_PUBLIC('opponents_full','plan')
MAIN_CSASS_PUBLIC('opponents_full','run')
```

Run one controller at a time. Each controller keeps its own output/lock directory. A retained interrupted trial is not silently overwritten or automatically retried. Keep the distributed `data/` and baseline cache files unchanged.

## Identity and cohort interpretation

The published main table uses 7,200 retained full-campaign opponent observations and 3,600 Missing8 observations, plus 2,160 current CSASS observations. The new `opponents_full` wrapper offers a complete independent reproduction of the retained five-opponent protocol; it does not falsely label newly generated results as the exact published cohort. To follow the recorded main cohort, use the group provenance table to choose the relevant full-campaign/Missing8 outputs.

The original campaign wrappers include verified immutable caches, so `benchmark` and `ablation10` are resumable campaign replays, not claims that every observation is freshly evaluated. The full-opponent and sensitivity wrappers were added for this release around the retained scientific implementations. They have passed syntax/dependency/preflight checks; no optimization was performed to validate these new packaging wrappers.

The historical `MAIN_CSASS_ALL` includes an old CSASS branch; do not use that entry for the current CSASS. The public `opponents_full` wrapper explicitly removes that branch. Core CSASS source bytes are unchanged, and all 21 core files match the benchmark, ablation and runtime implementations.

The bare core default options are not the manuscript protocol. The appropriate launchers explicitly select multiquadric RBF with shape 1 and the study settings. Some retained low-level/competitor output metrics use PF2000 internally; the manuscript metrics are separately recalculated from final sets with PF10000.

## Recompute paper metrics from newly generated sets

```text
python scripts/recalculate_new_finalsets.py --root . --runs reproduced/opponents_full/runs --output reproduced/opponents_full/metrics_PF10000.csv
```

Change `--runs` to the appropriate new run directory. This computes original-scale IGD and common-reference HV1.1 from saved final objectives. It does not change the search trajectory or the published data. New optimization results can vary with floating-point libraries or runtime conditions and remain separate from the frozen observations.

For verification of the actual published cohorts, use the three `verify_*` scripts described in the root README. Their complete checks have passed for this release.
