%% SETUP
% Add function paths
addpath('src/functions');
addpath('src/utils'); 
addpath('src/config');


config = default_config(); % Initialize config first
subject_id = 'CS_05_16_1'; % Subject to process

% Preprocessing
[success, EEG1, EEG2] = eeg_prepro('CS_05_16_1', config);

% Review preprocessed EEG
EEG = review_eeg_simple(subject_id, 'preprocessed', config);

% Train ICA weights
[success, EEG] = eeg_ica(subject_id, config);

% Artifact Correction, Epoching, and Artifact Rejection
[success, EEG] = eeg_epochs(subject_id, config);
% Inspect output/quality_control/individual_reports/ *artifact_rej_rep.mat

% Things to further inspect if problematic:

% rejected compoennts
EEG = review_eeg_simple(subject_id, 'components_rejected', config, opts);

% epoched data marked for rejection
EEG = review_eeg_simple(subject_id, 'epoched', config);








 

  % Review raw data
  EEG = review_eeg_data('CS_05_16_1', 'raw', config);

  % Review preprocessed data (default 0.1Hz)
  EEG = review_eeg_data('CS_05_16_1', 'preprocessed', config);

  % Review 1Hz preprocessed data
  opts.variant = '1Hz';
  EEG = review_eeg_data('CS_05_16_1', 'preprocessed', config, opts);

  % Review data with ICA weights applied
  EEG = review_eeg_data('CS_05_16_1', 'ica', config);

  % Review epoched data with plot view
  opts.gui_type = 'plot';
  EEG = review_eeg_data('CS_05_16_1', 'epoched', config, opts);

  % Initialize config
  config = default_config();

  % Review any stage - no more errors!
  
  EEG = review_eeg_simple('CS_05_16_1', 'ica', config);

  % Review 1Hz variant
  opts.variant = '1Hz';
  EEG = review_eeg_simple('CS_05_16_1', 'preprocessed', config, opts);

  EEG = eeg_ica('CS_05_16_1', config);

  