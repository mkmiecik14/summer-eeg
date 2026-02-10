%% ERPLAB PREPROCESSING PIPELINE
% This runs ERPLAB-based preprocessing for all subjects

clear; clc;

% Add function paths
addpath('src/functions');
addpath('src/utils');
addpath('src');

% Initialize EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Load configuration
config = default_config();

% Setup output directories
setup_output_directories(config);

% Setup pipeline diary logging
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
pipeline_log_dir = config.dirs.pipeline_logs;
if ~exist(pipeline_log_dir, 'dir'), mkdir(pipeline_log_dir); end
log_file = fullfile(pipeline_log_dir, ['run_erplab_prepro_' timestamp '.txt']);
diary(log_file);

% Load subject list
[NUM, TXT, RAW] = xlsread(fullfile(config.doc_dir, 'ss-info.xlsx'));
ss = string({RAW{2:size(RAW,1),1}});

fprintf('Starting ERPLAB preprocessing for %d subjects...\n', length(ss));

% Process each subject
success_count = 0;
failed_subjects = {};

for i = 1:length(ss)
    this_ss = ss{i};
    
    fprintf('\n=== Processing Subject %s (%d/%d) ===\n', this_ss, i, length(ss));
    
    try
        % Run ERPLAB preprocessing function
        [success, EEG] = erplab_prepro(this_ss, config);
        diary(log_file); % re-enable pipeline diary after core function

        if success
            success_count = success_count + 1;
            fprintf('✓ Subject %s completed successfully\n', this_ss);
        else
            failed_subjects{end+1} = this_ss;
            fprintf('✗ Subject %s failed\n', this_ss);
        end
        
    catch ME
        diary(log_file); % re-enable pipeline diary in case core function left it off
        failed_subjects{end+1} = this_ss;
        fprintf('✗ Subject %s crashed: %s\n', this_ss, ME.message);

        % Continue with next subject
        continue;
    end
end

% Summary
fprintf('\n=== ERPLAB PREPROCESSING COMPLETE ===\n');
fprintf('Successful: %d/%d subjects\n', success_count, length(ss));
fprintf('Failed: %d subjects\n', length(failed_subjects));

if ~isempty(failed_subjects)
    fprintf('Failed subjects: %s\n', strjoin(failed_subjects, ', '));
end

diary off;

% Redraw EEGLAB GUI
eeglab redraw;