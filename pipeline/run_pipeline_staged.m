% FILE: run_pipeline_staged.m (Main pipeline with stage-based organization)

%% EEG PROCESSING PIPELINE WITH STAGE-BASED ORGANIZATION
% This script runs the complete EEG preprocessing pipeline with organized
% output directories and comprehensive logging.
clear
clear; clc;

fprintf('==========================================================\n');
fprintf('EEG PROCESSING PIPELINE - STAGE-BASED ORGANIZATION\n');
fprintf('==========================================================\n');

%% SETUP
% Add function paths
addpath('src/functions');
addpath('src/utils');
addpath('src');

% Initialize EEGLAB
fprintf('Initializing EEGLAB...\n');
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Load configuration
config = default_config();

% Setup output directory structure
setup_output_directories(config);

% Validate configuration
fprintf('Validating configuration...\n');
if ~exist(config.data_dir, 'dir')
    error('Data directory not found: %s', config.data_dir);
end

fprintf('Configuration validated successfully.\n');

%% LOAD SUBJECT LIST
fprintf('Loading subject list...\n');
[NUM, TXT, RAW] = xlsread(fullfile(config.doc_dir, 'ss-info.xlsx'));
ss = string({RAW{2:size(RAW,1),1}});

fprintf('Found %d subjects to process.\n', length(ss));

%% PROCESSING OPTIONS
% You can modify these to run specific stages
run_preprocessing = true;
run_ica = true;
run_epoching = true;

% Or run specific subjects only
% subjects_to_process = ss;  % All subjects
subjects_to_process = ss(1:5); % First 5 subjects for testing

fprintf('Processing %d subjects through the following stages:\n', length(subjects_to_process));
if run_preprocessing, fprintf('  ✓ Preprocessing\n'); end
if run_ica, fprintf('  ✓ ICA Decomposition\n'); end
if run_epoching, fprintf('  ✓ Epoching & Artifact Rejection\n'); end

%% INITIALIZE LOGGING
pipeline_log = struct();
pipeline_log.start_time = datetime('now');
pipeline_log.config = config;
pipeline_log.subjects = subjects_to_process;
pipeline_log.stages = struct('preprocessing', run_preprocessing, 'ica', run_ica, 'epoching', run_epoching);

% Initialize subject tracking
for i = 1:length(subjects_to_process)
    pipeline_log.results(i).subject_id = subjects_to_process{i};
    pipeline_log.results(i).completed_stages = {};
    pipeline_log.results(i).errors = {};
    pipeline_log.results(i).processing_time = 0;
    pipeline_log.results(i).success = false;
end

total_start_time = tic;

%% MAIN PROCESSING LOOP
fprintf('\n=== STARTING PIPELINE PROCESSING ===\n');

for i = 1:length(subjects_to_process)
    subject_id = subjects_to_process{i};
    subject_start_time = tic;
    
    fprintf('\n--- Processing Subject %s (%d/%d) ---\n', subject_id, i, length(subjects_to_process));
    
    try
        %% STAGE 1: PREPROCESSING
        if run_preprocessing
            fprintf('STAGE 1: Preprocessing...\n');
            stage_start_time = tic;
            
            [success, EEG_01Hz, EEG_1Hz] = process_subject_preprocessing(subject_id, config);
            
            if success
                pipeline_log.results(i).completed_stages{end+1} = 'preprocessing';
                fprintf('  ✓ Preprocessing completed (%.1f s)\n', toc(stage_start_time));
            else
                error('Preprocessing failed');
            end
        end
        
        %% STAGE 2: ICA
        if run_ica
            fprintf('STAGE 2: ICA Decomposition...\n');
            stage_start_time = tic;
            
            [success, EEG_ica] = process_subject_ica(subject_id, config);
            
            if success
                pipeline_log.results(i).completed_stages{end+1} = 'ica';
                fprintf('  ✓ ICA completed (%.1f s)\n', toc(stage_start_time));
            else
                error('ICA failed');
            end
        end
        
        %% STAGE 3: EPOCHING & ARTIFACT REJECTION
        if run_epoching
            fprintf('STAGE 3: Epoching & Artifact Rejection...\n');
            stage_start_time = tic;
            
            [success, EEG_final] = process_subject_epochs(subject_id, config);
            
            if success
                pipeline_log.results(i).completed_stages{end+1} = 'epoching';
                fprintf('  ✓ Epoching completed (%.1f s)\n', toc(stage_start_time));
            else
                error('Epoching failed');
            end
        end
        
        %% SUBJECT COMPLETION
        pipeline_log.results(i).success = true;
        pipeline_log.results(i).processing_time = toc(subject_start_time);
        
        fprintf('✓ Subject %s completed successfully (%.1f minutes)\n', ...
            subject_id, pipeline_log.results(i).processing_time / 60);
        
        % Display progress
        display_progress_summary(i, length(subjects_to_process), pipeline_log, total_start_time);
        
    catch ME
        %% ERROR HANDLING
        pipeline_log.results(i).errors{end+1} = ME.message;
        pipeline_log.results(i).processing_time = toc(subject_start_time);
        
        fprintf('✗ Subject %s failed: %s\n', subject_id, ME.message);
        
        % Save detailed error information
        error_details = struct();
        error_details.subject_id = subject_id;
        error_details.error = ME;
        error_details.timestamp = datetime('now');
        error_details.completed_stages = pipeline_log.results(i).completed_stages;
        
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            sprintf('%s_pipeline_error_%s.mat', subject_id, datestr(now, 'yyyymmdd_HHMMSS')));
        save(error_file, 'error_details');
        
        % Continue with next subject
        continue;
    end
end

%% PIPELINE COMPLETION
pipeline_log.end_time = datetime('now');
pipeline_log.total_duration = toc(total_start_time);

% Generate comprehensive report
generate_pipeline_summary_report(pipeline_log, config);

% Final summary
successful_subjects = sum([pipeline_log.results.success]);
fprintf('\n==========================================================\n');
fprintf('PIPELINE COMPLETE\n');
fprintf('==========================================================\n');
fprintf('Successfully processed: %d/%d subjects (%.1f%%)\n', ...
    successful_subjects, length(subjects_to_process), ...
    (successful_subjects / length(subjects_to_process)) * 100);
fprintf('Total processing time: %.1f minutes\n', pipeline_log.total_duration / 60);
fprintf('Average time per subject: %.1f minutes\n', ...
    (pipeline_log.total_duration / length(subjects_to_process)) / 60);

if successful_subjects < length(subjects_to_process)
    failed_subjects = {pipeline_log.results(~[pipeline_log.results.success]).subject_id};
    fprintf('Failed subjects: %s\n', strjoin(failed_subjects, ', '));
end

fprintf('Reports saved to: %s\n', config.dirs.quality_control);
fprintf('Data organized in: %s\n', config.dirs.base);

% Redraw EEGLAB GUI
eeglab redraw;

%% HELPER FUNCTIONS

function display_progress_summary(current, total, pipeline_log, start_time)
    % Display progress summary with time estimates
    
    if current < 2, return; end  % Need at least 2 subjects for estimates
    
    elapsed_time = toc(start_time);
    successful = sum([pipeline_log.results(1:current).success]);
    
    avg_time_per_subject = elapsed_time / current;
    remaining_subjects = total - current;
    estimated_remaining = avg_time_per_subject * remaining_subjects;
    
    fprintf('\n--- PROGRESS SUMMARY ---\n');
    fprintf('Completed: %d/%d subjects (%.1f%%)\n', current, total, (current/total)*100);
    fprintf('Successful: %d (%.1f%% success rate)\n', successful, (successful/current)*100);
    fprintf('Elapsed time: %.1f minutes\n', elapsed_time / 60);
    fprintf('Estimated remaining: %.1f minutes\n', estimated_remaining / 60);
    fprintf('Estimated completion: %s\n', ...
        datestr(datetime('now') + minutes(estimated_remaining / 60), 'HH:MM'));
    fprintf('------------------------\n\n');
end

function generate_pipeline_summary_report(pipeline_log, config)
    % Generate comprehensive pipeline summary report
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    
    %% TEXT REPORT
    report_file = fullfile(config.dirs.quality_control, 'summary_reports', ...
        sprintf('pipeline_summary_%s.txt', timestamp));
    
    fid = fopen(report_file, 'w');
    
    fprintf(fid, '=== EEG PIPELINE PROCESSING REPORT ===\n\n');
    fprintf(fid, 'Processing Date: %s\n', datestr(pipeline_log.start_time));
    fprintf(fid, 'Completion Date: %s\n', datestr(pipeline_log.end_time));
    fprintf(fid, 'Total Duration: %.2f hours\n', pipeline_log.total_duration / 3600);
    fprintf(fid, '\n');
    
    % Summary statistics
    total_subjects = length(pipeline_log.results);
    successful = sum([pipeline_log.results.success]);
    
    fprintf(fid, '=== SUMMARY STATISTICS ===\n');
    fprintf(fid, 'Total Subjects: %d\n', total_subjects);
    fprintf(fid, 'Successful: %d (%.1f%%)\n', successful, (successful/total_subjects)*100);
    fprintf(fid, 'Failed: %d (%.1f%%)\n', total_subjects - successful, ((total_subjects - successful)/total_subjects)*100);
    fprintf(fid, 'Average Processing Time: %.2f minutes per subject\n', ...
        mean([pipeline_log.results.processing_time]) / 60);
    fprintf(fid, '\n');
    
    % Stage completion statistics
    fprintf(fid, '=== STAGE COMPLETION RATES ===\n');
    stages = {'preprocessing', 'ica', 'epoching'};
    for s = 1:length(stages)
        stage_completions = 0;
        for subj = 1:length(pipeline_log.results)
            if any(strcmp(pipeline_log.results(subj).completed_stages, stages{s}))
                stage_completions = stage_completions + 1;
            end
        end
        fprintf(fid, '%s: %d/%d subjects (%.1f%%)\n', ...
            stages{s}, stage_completions, total_subjects, ...
            (stage_completions/total_subjects)*100);
    end
    fprintf(fid, '\n');
    
    % Individual subject results
    fprintf(fid, '=== INDIVIDUAL SUBJECT RESULTS ===\n');
    for i = 1:length(pipeline_log.results)
        result = pipeline_log.results(i);
        fprintf(fid, '\nSubject: %s\n', result.subject_id);
        fprintf(fid, '  Status: %s\n', iif(result.success, 'SUCCESS', 'FAILED'));
        fprintf(fid, '  Processing Time: %.2f minutes\n', result.processing_time / 60);
        fprintf(fid, '  Completed Stages: %s\n', strjoin(result.completed_stages, ', '));
        if ~isempty(result.errors)
            fprintf(fid, '  Errors: %s\n', strjoin(result.errors, '; '));
        end
    end
    
    fclose(fid);
    
    %% SAVE MATLAB STRUCTURE
    save(fullfile(config.dirs.logs, sprintf('pipeline_log_%s.mat', timestamp)), 'pipeline_log');
    
    fprintf('Pipeline report saved: %s\n', report_file);
end

function result = iif(condition, true_value, false_value)
    % Inline if function
    if condition
        result = true_value;
    else
        result = false_value;
    end
end