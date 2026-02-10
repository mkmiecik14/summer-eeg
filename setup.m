%% PROJECT SETUP
% Run this script once after opening MATLAB and navigating to the project
% root directory. It adds all necessary paths and initializes EEGLAB.
%
% Usage:
%   1. Open MATLAB
%   2. Navigate to the project root (summer-eeg/)
%   3. Run: setup
%   4. Run any pipeline script, e.g.: run_erplab_prepro
%
% After running this script, all pipeline scripts (in pipeline/) and core
% functions (in src/) will be available from the command window without
% needing to cd into their directories.

fprintf('Setting up EEG processing pipeline...\n');

% Verify we are in the project root
if ~exist('src/default_config.m', 'file')
    error(['setup.m must be run from the project root directory.\n' ...
           'Current directory: %s'], pwd);
end

% Add source paths
addpath('src');
addpath('src/functions');
addpath('src/utils');

% Add pipeline scripts to path so they can be called from anywhere
addpath('pipeline');

% Initialize EEGLAB (suppresses GUI if already running)
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Setup output directories
config = default_config();
setup_output_directories(config);

fprintf('Setup complete. You can now run pipeline scripts, e.g.:\n');
fprintf('  run_erplab_prepro\n');
fprintf('  run_erplab_artifact_rejection\n');
fprintf('  run_eeglab_prepro\n');
fprintf('  run_ica\n');
fprintf('  run_epoching\n');
