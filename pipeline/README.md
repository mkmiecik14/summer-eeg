# pipeline/

Batch processing scripts that run each pipeline stage across all subjects. Execute these from the MATLAB command window after running `setup`.

## Scripts (intended execution order)

| # | Script | Description |
|---|--------|-------------|
| 1 | `run_eeglab_prepro.m` | EEGLAB preprocessing for all subjects (filtering, re-referencing, CleanLine) |
| 2 | `run_eeglab_ica.m` | ICA decomposition for all subjects (saves lightweight weight files) |
| 3 | `run_eeglab_epoching.m` | EEGLAB epoching and artifact rejection for all subjects (applies ICA, epochs, threshold rejection) |
| 4 | `run_erplab_prepro.m` | ERPLAB preprocessing for all subjects (bandpass filter, epoch, baseline) |
| 5 | `run_erplab_epoching.m` | ERPLAB 5-step artifact rejection for all subjects |
| 6 | `run_combine_extract.m` | Combines EEGLAB + ERPLAB rejection markers and extracts results for all subjects |

Steps 1-3 (EEGLAB) and steps 4-5 (ERPLAB) are independent and can be run in either order, meaning you can run 4-5 then 1-3. Both must complete before step 6.

## Meta-pipeline scripts

These scripts run multiple stages in sequence:

| Script | Stages | Description |
|--------|--------|-------------|
| `run_eeglab_pipeline.m` | 1-3 | Runs EEGLAB preprocessing, ICA, and epoching |
| `run_erplab_pipeline.m` | 4-5 | Runs ERPLAB preprocessing and artifact rejection |
| `run_entire_pipeline.m` | 1-6 | Runs all stages end-to-end |
