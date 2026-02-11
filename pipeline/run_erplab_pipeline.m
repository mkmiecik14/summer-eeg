%% FULL ERPLAB PIPELINE
% Orchestrates: run_erplab_prepro -> run_erplab_epoching

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
log_file = fullfile(pipeline_log_dir, ['run_erplab_pipeline_' timestamp '.txt']);
diary(log_file);

pipeline_start = tic;
fprintf('========================================\n');
fprintf('  FULL ERPLAB PIPELINE\n');
fprintf('  Started: %s\n', datestr(now));
fprintf('========================================\n\n');

%% Step 1: ERPLAB Preprocessing
fprintf('########################################\n');
fprintf('  STEP 1/2: ERPLAB Preprocessing\n');
fprintf('########################################\n');
step_start = tic;
run_erplab_prepro;
diary(log_file);
fprintf('Step 1 completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Step 2: ERPLAB Artifact Rejection
fprintf('########################################\n');
fprintf('  STEP 2/2: ERPLAB Artifact Rejection\n');
fprintf('########################################\n');
step_start = tic;
run_erplab_epoching;
diary(log_file);
fprintf('Step 2 completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Summary
fprintf('========================================\n');
fprintf('  ERPLAB PIPELINE COMPLETE\n');
fprintf('  Total elapsed time: %.1f minutes\n', toc(pipeline_start)/60);
fprintf('  Finished: %s\n', datestr(now));
fprintf('========================================\n');

diary off;
eeglab redraw;
