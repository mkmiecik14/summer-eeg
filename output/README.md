# output/

All processing output is saved here, organized by pipeline stage. These directories are created automatically when you run `setup` in MATLAB.

**Note**: All output is gitignored. Re-run the pipeline to regenerate.

## Stage directories

| Directory | Stage | Contents |
|-----------|-------|----------|
| `01_preprocessed/` | Preprocessing | Filtered and re-referenced `.set` files (both 0.1 Hz and 1 Hz variants, plus ERPLAB versions) |
| `02_ica/` | ICA | Lightweight `.mat` files containing ICA weight matrices (not full datasets) |
| `03_components_rejected/` | Component rejection | Datasets after ICA component removal (intermediate; used during epoching) |
| `04_epoched/` | Epoching | Segmented data around stimulus events (both EEGLAB and ERPLAB versions) |
| `05_artifacts_rejected/` | Artifact rejection | Clean epoched data after threshold/artifact rejection (both pipelines) |
| `06_final/` | Final | Analysis-ready datasets after merging both pipelines' rejection decisions, plus extracted `.mat` results |
| `logs/` | Logging | Per-subject text logs captured via MATLAB's `diary()` function |

## Log files

Each processing function creates a timestamped log file in `logs/<subject_id>/`:

```
logs/
├── CS_05_16_1/
│   ├── CS_05_16_1_eeg_prepro_20260209_143022.txt
│   ├── CS_05_16_1_eeg_ica_20260209_144511.txt
│   └── ...
└── pipeline/
    └── (batch processing logs)
```

## File naming conventions

- EEGLAB files: `<subject>-prepro.set`, `<subject>-epochs.set`, `<subject>-art-rej.set`
- ERPLAB files: `<subject>-prepro-erplab.set`, `<subject>-epochs-erplab.set`, `<subject>-art-rej-erplab.set`
- Final files: `<subject>-final.set`, `<subject>-final.mat`
- ICA weights: `<subject>-ica-1Hz.mat`
