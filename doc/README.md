# doc/

Documentation and channel information for the EEG pipeline.

## Required files

| File | Description | Checked in? |
|------|-------------|-------------|
| `ss-info.xlsx` | Subject list and bad channel information. Column 1 = subject ID (must match `.bdf` filename), Column 2 = bad channel indices (comma-separated integers, or empty). | No — contains participant info. Must be added manually. |
| `chan_info_nose_along_fixed.mat` | Channel metadata structure used during preprocessing. | Yes |
| `chan_locs_nose_along_fixed.mat` | 64-channel electrode locations for EEGLAB (nose-along orientation). Used for topographic plots and channel interpolation. | Yes |

## Editing the subject list

To add or modify subjects, open `ss-info.xlsx` in Excel or MATLAB:

- **Column 1**: Subject ID string (e.g., `MC_07_06_2`). Must exactly match the `.bdf` filename in `data/`.
- **Column 2**: Bad channel indices as a comma-separated list (e.g., `5, 32`). Leave empty if no bad channels. Channel numbers correspond to the 64-channel A1-B32 montage.
