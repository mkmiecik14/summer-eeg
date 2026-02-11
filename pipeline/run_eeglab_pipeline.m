%% FULL EEGLAB PIPELINE
% Orchestrates: run_eeglab_prepro -> run_eeglab_ica -> run_eeglab_epoching

% Add function paths
addpath('src/functions');
addpath('src/utils');
addpath('src');

% Initialize EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Load configuration
config = default_config();

% Setup pipeline diary logging
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
pipeline_log_dir = config.dirs.pipeline_logs;
if ~exist(pipeline_log_dir, 'dir'), mkdir(pipeline_log_dir); end
log_file = fullfile(pipeline_log_dir, ['run_eeglab_pipeline_' timestamp '.txt']);
diary(log_file);

pipeline_start = tic;
fprintf('========================================\n');
fprintf('  FULL EEGLAB PIPELINE\n');
fprintf('  Started: %s\n', datestr(now));
fprintf('========================================\n\n');

%% Step 1: Preprocessing
fprintf('########################################\n');
fprintf('  STEP 1/3: EEGLAB Preprocessing\n');
fprintf('########################################\n');
step_start = tic;
run_eeglab_prepro;
diary(log_file);
fprintf('Step 1 completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Step 2: ICA
fprintf('########################################\n');
fprintf('  STEP 2/3: ICA Decomposition\n');
fprintf('########################################\n');
step_start = tic;
run_eeglab_ica;
diary(log_file);
fprintf('Step 2 completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Step 3: Epoching
fprintf('########################################\n');
fprintf('  STEP 3/3: Epoching & Artifact Rejection\n');
fprintf('########################################\n');
step_start = tic;
run_eeglab_epoching;
diary(log_file);
fprintf('Step 3 completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Summary
fprintf('========================================\n');
fprintf('  EEGLAB PIPELINE COMPLETE\n');
fprintf('  Total elapsed time: %.1f minutes\n', toc(pipeline_start)/60);
fprintf('  Finished: %s\n', datestr(now));
fprintf('========================================\n');

diary off;
eeglab redraw;
