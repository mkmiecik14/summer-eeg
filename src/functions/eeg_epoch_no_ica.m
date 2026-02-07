function [success, EEG] = eeg_epoch_no_ica(subject_id, config)
    % EEG_EPOCHS - EEGLAB-based epoching and artifact rejection pipeline
    %
    % EEG_EPOCHS performs the complete epoching workflow using EEGLAB tools,
    % including ICA component rejection, event-based segmentation, baseline
    % correction, and amplitude-based artifact rejection. Uses space-efficient
    % ICA weight loading and stage-based data organization.
    %
    % Syntax: 
    %   [success, EEG] = eeg_epochs(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'jerry')
    %   config     - Configuration structure from default_config() containing:
    %                .event_codes          - Cell array of event codes to epoch
    %                .epoch_window         - Time window for epochs [start end] (s)
    %                .amplitude_threshold  - Artifact rejection threshold (µV)
    %                .ica_rejection        - ICA component rejection thresholds
    %                .dirs                 - Stage directory paths
    %                .naming               - File naming conventions
    %
    % Outputs:
    %   success - Logical, true if processing completed successfully
    %   EEG     - Final EEGLAB EEG structure with clean epochs
    %
    % Processing Pipeline:
    %   1. Load 0.1Hz preprocessed data from stage directory
    %   2. Apply ICA weights using space-efficient loading
    %   3. Run ICLabel for automatic component classification
    %   4. Reject muscle and eye artifact components using pop_icflag
    %   5. Remove flagged components with pop_subcomp
    %   6. Create epochs around specified event codes
    %   7. Apply baseline correction (epoch start to 0ms)
    %   8. Mark trials exceeding amplitude threshold
    %   9. Save epoched data with rejection markers
    %   10. Physically remove marked trials
    %   11. Generate artifact rejection report
    %   12. Save final clean data
    %
    % ICA Component Rejection:
    %   Uses ICLabel probability thresholds from config:
    %   - Muscle artifacts: config.ica_rejection.muscle_threshold (default 0.8)
    %   - Eye artifacts: config.ica_rejection.eye_threshold (default 0.8)
    %   - Brain components: preserved (NaN threshold)
    %
    % Artifact Rejection:
    %   - Amplitude-based using pop_eegthresh()
    %   - Threshold: ±config.amplitude_threshold µV (default ±100µV)
    %   - Applied to all channels across entire epoch
    %   - Two-stage process: mark then physically remove
    %
    % Stage Output:
    %   - components_rejected: Data after ICA component removal
    %   - epoched: Segmented data with rejection markers
    %   - artifacts_rejected: Final clean epochs
    %   - quality_control/individual_reports: Rejection statistics
    %
    % Examples:
    %   % Run complete epoching pipeline
    %   config = default_config();
    %   [success, EEG] = eeg_epochs('elaine', config);
    %
    %   % Check processing success
    %   if success
    %       fprintf('Epoching completed successfully\n');
    %   end
    %
    % Error Handling:
    %   - Comprehensive try-catch with detailed error logging
    %   - Error files saved to: output/logs/error_logs/
    %   - Processing continues with other subjects on failure
    %   - Returns success=false on any processing error
    %
    % Quality Control:
    %   - Automatic rejection rate calculation and reporting
    %   - Individual subject reports saved with timestamps
    %   - Logs initial vs final trial counts
    %   - Warning for high rejection rates
    %
    % Notes:
    %   - Requires preprocessed data and ICA weights from previous stages
    %   - Uses 0.1Hz preprocessed data (optimal for epoching)
    %   - Baseline correction uses epoch start to 0ms window
    %   - ICLabel requires EEGLAB 2019.1+ with ICLabel plugin
    %   - Automatically initializes EEGLAB if needed
    %
    % See also: eeg_ica, eeg_prepro, pop_epoch, pop_iclabel, load_ica_weights
    %
    % Author: Matt Kmiecik
    
    success = false;
    
    fprintf('=== EPOCHING SUBJECT: %s ===\n', subject_id);
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
    end
    
    try
        %% LOAD DATA AND APPLY ICA WEIGHTS
        fprintf('  Loading 0.1Hz preprocessed data...\n');
        [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config);
        
        % Load and apply ICA weights from lightweight file
        fprintf('  Loading and applying ICA weights...\n');
        EEG = load_ica_weights(EEG, subject_id, config);
        
        %% IC LABELING AND ARTIFACT CORRECTION
        fprintf('  Labeling and rejecting IC components...\n');
        EEG = pop_iclabel(EEG, 'default');
        EEG = pop_icflag(EEG, ...
            [NaN NaN;...    % brain
            config.ica_rejection.muscle_threshold 1;...  % muscle
            config.ica_rejection.eye_threshold 1;...     % eye
            NaN NaN;...     % heart
            NaN NaN;...     % line noise
            NaN NaN;...     % channel noise
            NaN NaN...      % other
            ]);
        
        %% CREATE EPOCHS
        fprintf('  Creating epochs...\n');
        EEG = pop_epoch(EEG, config.event_codes, config.epoch_window);
        
        % Baseline correction
        fprintf('  Applying baseline correction...\n');
        EEG = pop_rmbase(EEG, [EEG.xmin 0]);
        
        %% ARTIFACT REJECTION
        fprintf('  Running artifact rejection...\n');
        initial_trials = EEG.trials;
        
        % Amplitude-based rejection (mark but don't remove yet)
        EEG = pop_eegthresh(EEG, 1, [1:64], -config.amplitude_threshold, ...
            config.amplitude_threshold, EEG.xmin, EEG.xmax, 0, 0);
        
        % % Save epoched data with rejection markers
        % fprintf('  Saving epoched data with rejection markers...\n');
        % EEG = save_eeg_to_stage(EEG, subject_id, 'epoched', config);
        % 
        % % Now actually remove rejected trials
        % EEG = pop_rejepoch(EEG, find(EEG.reject.rejthresh), 0);
        % 
        % % Update EEG structure
        % [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
        % 
        % final_trials = EEG.trials;
        % rejected_trials = initial_trials - final_trials;
        % rejection_rate = (rejected_trials / initial_trials) * 100;
        % 
        % fprintf('  Rejected %d trials (%.1f%% rejection rate)\n', ...
        %     rejected_trials, rejection_rate);
        % 
        % % Save artifact rejection report
        % rejection_report = struct();
        % rejection_report.subject_id = subject_id;
        % rejection_report.initial_trials = initial_trials;
        % rejection_report.final_trials = final_trials;
        % rejection_report.rejected_trials = rejected_trials;
        % rejection_report.rejection_rate = rejection_rate;
        % rejection_report.threshold = config.amplitude_threshold;
        % rejection_report.timestamp = datetime('now');
        % 
        % report_file = fullfile(config.dirs.quality_control, 'individual_reports', ...
        %     [subject_id '_artifact_rejection_report.mat']);
        % save(report_file, 'rejection_report');
        % 
        % %% SAVE FINAL CLEAN AND ARTIFACT REJECTED DATA
        % fprintf('  Saving artifact-rejected data...\n');
        % EEG = save_eeg_to_stage(EEG, subject_id, 'artifacts_rejected', config);
        % 
        success = true;
        % fprintf('  Epoching completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in epoching %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_epoching_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end