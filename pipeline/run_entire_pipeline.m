%% ENTIRE PIPELINE
% Orchestrates: run_eeglab_pipeline -> run_erplab_pipeline -> run_combine_extract

clear; clc;

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
log_file = fullfile(pipeline_log_dir, ['run_entire_pipeline_' timestamp '.txt']);
diary(log_file);

pipeline_start = tic;
fprintf('========================================\n');
fprintf('  ENTIRE PIPELINE\n');
fprintf('  Started: %s\n', datestr(now));
fprintf('========================================\n\n');

%% Step 1: EEGLAB Pipeline
fprintf('########################################\n');
fprintf('  STEP 1/3: Full EEGLAB Pipeline\n');
fprintf('########################################\n');
step_start = tic;
run_eeglab_pipeline;
diary(log_file);
fprintf('Step 1 (EEGLAB) completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Step 2: ERPLAB Pipeline
fprintf('########################################\n');
fprintf('  STEP 2/3: Full ERPLAB Pipeline\n');
fprintf('########################################\n');
step_start = tic;
run_erplab_pipeline;
diary(log_file);
fprintf('Step 2 (ERPLAB) completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Step 3: Combine Markers & Extract Results
fprintf('########################################\n');
fprintf('  STEP 3/3: Combine Markers & Extract Results\n');
fprintf('########################################\n');
step_start = tic;
run_combine_extract;
diary(log_file);
fprintf('Step 3 (Combine + Extract) completed in %.1f minutes.\n\n', toc(step_start)/60);

%% Summary
fprintf('========================================\n');
fprintf('  ENTIRE PIPELINE COMPLETE\n');
fprintf('  Total elapsed time: %.1f minutes\n', toc(pipeline_start)/60);
fprintf('  Finished: %s\n', datestr(now));
fprintf('========================================\n');

diary off;
eeglab redraw;
