# src/

Source code for the EEG processing pipeline, organized into core processing functions, utility helpers, and central configuration.

## Configuration

- **`default_config.m`** — Central configuration file. All processing parameters, file paths, naming conventions, and thresholds are defined here. This is the single place to adjust pipeline behavior.

## functions/

Core processing functions that implement each pipeline stage.

| File | Description |
|------|-------------|
| `eeg_prepro.m` | EEGLAB preprocessing: loads `.bdf`, removes external channels, re-references, resamples, applies CleanLine, saves 0.1 Hz and 1 Hz filtered versions |
| `eeg_ica.m` | ICA decomposition: removes bad channels, runs ICA on 1 Hz data, saves lightweight weight matrices |
| `eeg_epochs.m` | EEGLAB epoching: loads ICA weights, rejects components via ICLabel, interpolates channels back, epochs, baseline correction, amplitude rejection |
| `erplab_prepro.m` | ERPLAB preprocessing: bandpass filter, re-reference, resample, epoch, baseline correction |
| `erplab_art_rej.m` | ERPLAB 5-step artifact rejection: extreme values, peak-to-peak, step, trend, flatline detection |
| `combine_markers.m` | Merges EEGLAB and ERPLAB rejection markers (logical OR) and removes flagged epochs |
| `extract_results.m` | Exports final clean data as structured `.mat` with data matrix, time vector, channel labels, triggers, and original trial numbers |

## utils/

Helper functions used by the core processing functions.

| File | Description |
|------|-------------|
| `setup_output_directories.m` | Creates the stage-based output directory structure |
| `load_eeg_from_stage.m` | Loads an EEG dataset from a named processing stage |
| `save_eeg_to_stage.m` | Saves an EEG dataset to a named processing stage |
| `save_ica_weights.m` | Saves ICA weight matrices as lightweight `.mat` files |
| `load_ica_weights.m` | Loads and applies ICA weights with dimension validation |
| `apply_cleanline_to_eeg.m` | Removes 60 Hz line noise using CleanLine |
| `get_bad_channels_from_excel.m` | Reads bad channel info from `ss-info.xlsx` |
| `review_eeg_simple.m` | Interactive data review tool for any stage and pipeline type |
| `run_quality_control.m` | Quality control analysis and reporting |
| `load_subject_data.m` | Standardized subject data loading |
| `save_eeg_dataset.m` | General-purpose EEG dataset saving |
