% FILE: run_preprocessing.m (in main project directory)

%% SIMPLE PREPROCESSING PIPELINE
% This replaces current eeg_prepro.m for loop

clear; clc;

% Add function paths
addpath('src/functions');
addpath('src/utils');
addpath('src');

% Initialize EEGLAB
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Load configuration
config = default_config();

% Load subject list (from your original workspace_prep.m approach)
[NUM, TXT, RAW] = xlsread(fullfile(config.doc_dir, 'ss-info.xlsx'));
ss = string({RAW{2:size(RAW,1),1}});

fprintf('Starting preprocessing for %d subjects...\n', length(ss));

% Process each subject
success_count = 0;
failed_subjects = {};

for i = 1:length(ss)
    this_ss = ss{i};
    
    fprintf('\n=== Processing Subject %s (%d/%d) ===\n', this_ss, i, length(ss));
    
    try
        % Run preprocessing function
        [success, EEG_01Hz, EEG_1Hz] = eeg_prepro(this_ss, config);
        
        if success
            success_count = success_count + 1;
            fprintf('✓ Subject %s completed successfully\n', this_ss);
        else
            failed_subjects{end+1} = this_ss;
            fprintf('✗ Subject %s failed\n', this_ss);
        end
        
    catch ME
        failed_subjects{end+1} = this_ss;
        fprintf('✗ Subject %s crashed: %s\n', this_ss, ME.message);
        
        % Save error for later analysis
        error_file = fullfile(config.output_dir, [this_ss '_preprocessing_error.mat']);
        save(error_file, 'ME');
        
        % Continue with next subject
        continue;
    end
end

% Summary
fprintf('\n=== PREPROCESSING COMPLETE ===\n');
fprintf('Successful: %d/%d subjects\n', success_count, length(ss));
fprintf('Failed: %d subjects\n', length(failed_subjects));

if ~isempty(failed_subjects)
    fprintf('Failed subjects: %s\n', strjoin(failed_subjects, ', '));
end

% Redraw EEGLAB GUI
eeglab redraw;