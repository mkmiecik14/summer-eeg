# data/

This directory holds raw EEG data files. These files are too large for git and must be obtained from lab storage.

## Contents

### Raw EEG recordings (`.bdf`)

Place BioSemi 64-channel `.bdf` files here. Each file is typically ~1 GB.

**Naming convention**: The filename (without extension) must match the subject ID in `doc/ss-info.xlsx`. For example, if the subject list contains `CS_05_16_1`, the file should be named `CS_05_16_1.bdf`.

### Marker version files (`eeg_vers_*.mat`)

Some subjects have associated marker version `.mat` files that contain event code metadata. These follow the naming pattern `eeg_vers_<subject>.mat` (note: spaces may appear in the filename).

## Adding new subjects/batch processing

1. Place the `.bdf` file in this directory
2. Add the subject ID to `doc/ss-info.xlsx` (column 1, sheet 1)
3. If the subject has bad channels, list their indices in column 2, sheet 1
4. Run the pipeline as desired (see `./README.md`)
