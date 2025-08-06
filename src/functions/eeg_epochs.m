% FILE: src/functions/eeg_epochs.m (Updated for stage-based organization)

function [success, EEG] = eeg_epochs(subject_id, config)
    % EEG_EPOCHS - Epoching and artifact rejection with stage-based organization
    
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
        
        % Remove artifactual ICs
        rejected_components = find(EEG.reject.gcompreject);
        if ~isempty(rejected_components)
            fprintf('  Rejecting %d IC components\n', length(rejected_components));
            EEG = pop_subcomp(EEG, rejected_components, 0);
        else
            fprintf('  No IC components rejected\n');
        end
        
        % Save after component rejection
        fprintf('  Saving component-rejected data...\n');
        EEG = save_eeg_to_stage(EEG, subject_id, 'components_rejected', config);
        
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
        
        % Save epoched data with rejection markers
        fprintf('  Saving epoched data with rejection markers...\n');
        EEG = save_eeg_to_stage(EEG, subject_id, 'epoched', config);
        
        % Now actually remove rejected trials
        EEG = pop_eegthresh(EEG, 1, [1:64], -config.amplitude_threshold, ...
            config.amplitude_threshold, EEG.xmin, EEG.xmax, 0, 1);
        
        % Update EEG structure
        [ALLEEG, EEG, CURRENTSET] = pop_newset(ALLEEG, EEG, 1, 'overwrite', 'on', 'gui', 'off');
        
        final_trials = EEG.trials;
        rejected_trials = initial_trials - final_trials;
        rejection_rate = (rejected_trials / initial_trials) * 100;
        
        fprintf('  Rejected %d trials (%.1f%% rejection rate)\n', ...
            rejected_trials, rejection_rate);
        
        % Save artifact rejection report
        rejection_report = struct();
        rejection_report.subject_id = subject_id;
        rejection_report.initial_trials = initial_trials;
        rejection_report.final_trials = final_trials;
        rejection_report.rejected_trials = rejected_trials;
        rejection_report.rejection_rate = rejection_rate;
        rejection_report.threshold = config.amplitude_threshold;
        rejection_report.timestamp = datetime('now');
        
        report_file = fullfile(config.dirs.quality_control, 'individual_reports', ...
            [subject_id '_artifact_rejection_report.mat']);
        save(report_file, 'rejection_report');
        
        %% SAVE FINAL CLEAN AND ARTIFACT REJECTED DATA
        fprintf('  Saving artifact-rejected data...\n');
        EEG = save_eeg_to_stage(EEG, subject_id, 'artifacts_rejected', config);
        
        success = true;
        fprintf('  Epoching completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in epoching %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_epoching_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end