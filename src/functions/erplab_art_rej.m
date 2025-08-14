% FILE: src/functions/erplab_art_rej.m

function [success, EEG] = erplab_art_rej(subject_id, config)
    % ERPLAB_ART_REJ - ERPLAB-based artifact rejection from preprocessed data
    
    success = false;
    EEG = [];
    
    fprintf('=== ERPLAB ARTIFACT REJECTION: %s ===\n', subject_id);

    % Add ERPLAB path explicitly
    if exist(config.erplab_dir, 'dir')
        addpath(genpath(config.erplab_dir));
    end
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
        
        % Verify ERPLAB is available
        if exist('pop_artmwppth', 'file') ~= 2
            warning('ERPLAB functions may not be available');
        end
    end
    
    try
        %% LOAD PREPROCESSED DATA FROM 02_PREPROCESSED
        fprintf('  Loading preprocessed data...\n');
        prepro_filename = sprintf(config.naming.preprocessed_erplab, subject_id);
        EEG = pop_loadset('filename', [prepro_filename '.set'], ...
            'filepath', config.dirs.preprocessed);

        %% CREATE BASIC EVENTLIST FOR ERPLAB
        fprintf('  Creating ERPLAB eventlist...\n');
        EEG = pop_creabasiceventlist(EEG, 'AlphanumericCleaning', 'on', ...
            'BoundaryNumeric', {-99}, 'BoundaryString', {'boundary'});
        
        %% EPOCH DATA
        fprintf('  Creating epochs...\n');
        EEG = pop_epoch(EEG, config.event_codes, config.erplab_art_rej.epoch_window);
        
        %% BASELINE CORRECT FROM -200ms TO 0ms
        fprintf('  Applying baseline correction...\n');
        EEG = pop_rmbase(EEG, config.erplab_art_rej.baseline_window);
        
        %% EOG ARTIFACT REJECTION (SKIPPED)
        % EOG artifact rejection would go here but is skipped as requested
        fprintf('  EOG artifact rejection: SKIPPED\n');
        
        %% EEG ARTIFACT REJECTION
        fprintf('  Running ERPLAB artifact rejection...\n');
        
        % Get EEG channel indices (exclude external channels)
        eeg_channels = 1:EEG.nbchan;
        %for ext_ch = config.external_channels
        %    ch_idx = find(strcmp({EEG.chanlocs.labels}, ext_ch));
        %    if ~isempty(ch_idx)
        %        eeg_channels(eeg_channels == ch_idx) = [];
        %    end
        %end
        
        % Step 1: Flag trials where absolute EEG value is greater than ±100 microvolts
        fprintf('    Step 1: Extreme values (±%d µV)...\n', ...
            config.erplab_art_rej.extreme_values_threshold);
        EEG = pop_artextval(EEG, 'Channel', eeg_channels, ...
            'Flag', 1, ...
            'Threshold', [-config.erplab_art_rej.extreme_values_threshold ...
                         config.erplab_art_rej.extreme_values_threshold], ...
            'Twindow', [EEG.xmin EEG.xmax]*1000);
        
        % Step 2: Flag trials with peak-to-peak activity > ±75 microvolts in moving window
        fprintf('    Step 2: Peak-to-peak (±%d µV, %dms window, %dms step)...\n', ...
            config.erplab_art_rej.peak_to_peak_threshold, ...
            config.erplab_art_rej.peak_to_peak_window_size, ...
            config.erplab_art_rej.peak_to_peak_window_step);
        EEG = pop_artmwppth(EEG, 'Channel', eeg_channels, ...
            'Flag', 1, ...
            'Threshold', config.erplab_art_rej.peak_to_peak_threshold, ...
            'Twindow', [EEG.xmin EEG.xmax]*1000, ...
            'Windowsize', config.erplab_art_rej.peak_to_peak_window_size, ...
            'Windowstep', config.erplab_art_rej.peak_to_peak_window_step);
        
        % Step 3: Flag trials with step-like activity > ±60 microvolts
        fprintf('    Step 3: Step-like artifacts (±%d µV, %dms window, %dms step)...\n', ...
            config.erplab_art_rej.step_threshold, ...
            config.erplab_art_rej.step_window_size, ...
            config.erplab_art_rej.step_window_step);
        EEG = pop_artstep(EEG, 'Channel', eeg_channels, ...
            'Flag', 1, ...
            'Threshold', config.erplab_art_rej.step_threshold, ...
            'Twindow', [EEG.xmin EEG.xmax]*1000, ...
            'Windowsize', config.erplab_art_rej.step_window_size, ...
            'Windowstep', config.erplab_art_rej.step_window_step);
        
        % Step 4: Flag trials with linear trends (slope threshold)
        fprintf('    Step 4: Linear trends (slope>%d, R²>%.1f)...\n', ...
            config.erplab_art_rej.trend_min_slope, ...
            config.erplab_art_rej.trend_min_r2);
        EEG = pop_rejtrend(EEG, 1, eeg_channels, EEG.pnts, ...
            config.erplab_art_rej.trend_min_slope, ...
            config.erplab_art_rej.trend_min_r2, 0, 0);
        
        % Step 5: Flag trials where any channel has flatlined completely
        fprintf('    Step 5: Flatline detection...\n');
        EEG = pop_artflatline(EEG, 'Channel', eeg_channels, ...
            'Flag', 1, ...
            'Threshold', [0 0], ...  % Detect completely flat channels
            'Twindow', [EEG.xmin EEG.xmax]*1000);
        
        %% SYNC REJECTION FLAGS FOR ERPLAB AND EEGLAB FUNCTIONS
        fprintf('  Syncing artifact rejection flags...\n');
        EEG = pop_syncroartifacts(EEG, 'Direction', 'bidirectional');
        
        %% SAVE EPOCHED DATA WITH REJECTION MARKERS TO 05_EPOCHED
        fprintf('  Saving epoched data with rejection markers...\n');
        epoched_filename = sprintf(config.naming.epoched_erplab, subject_id);
        EEG_epoched = pop_saveset(EEG, 'filename', [epoched_filename '.set'], ...
            'filepath', config.dirs.epoched);
        
        %% ACTUALLY REJECT MARKED EPOCHS
        fprintf('  Rejecting marked epochs...\n');
        if isfield(EEG.reject, 'rejmanual') && any(EEG.reject.rejmanual)
            rejected_count = sum(EEG.reject.rejmanual);
            fprintf('    Removing %d rejected epochs from dataset...\n', rejected_count);
            EEG = pop_rejepoch(EEG, find(EEG.reject.rejmanual), 0);
        else
            fprintf('    No epochs marked for rejection\n');
        end
        
        %% SAVE ARTIFACT REJECTED DATA
        fprintf('  Saving artifact-rejected data...\n');
        art_rej_filename = sprintf(config.naming.artifacts_rejected_erplab, subject_id);
        EEG = pop_saveset(EEG, 'filename', [art_rej_filename '.set'], ...
            'filepath', config.dirs.artifacts_rejected);
        
        %% GENERATE ARTIFACT REJECTION REPORT
        % Note: epochs are now actually removed, so we need to track before rejection
        if exist('rejected_count', 'var')
            final_trials = EEG.trials;
            initial_trials = final_trials + rejected_count;
            rejected_trials = rejected_count;
        else
            initial_trials = EEG.trials;
            rejected_trials = 0;
            final_trials = initial_trials;
        end
        rejection_rate = (rejected_trials / initial_trials) * 100;
        
        fprintf('  Artifact rejection summary:\n');
        fprintf('    Initial trials: %d\n', initial_trials);
        fprintf('    Rejected trials: %d (%.1f%%)\n', rejected_trials, rejection_rate);
        fprintf('    Final trials: %d\n', final_trials);
        
        % Save rejection report
        rejection_report = struct();
        rejection_report.subject_id = subject_id;
        rejection_report.method = 'ERPLAB';
        rejection_report.initial_trials = initial_trials;
        rejection_report.final_trials = final_trials;
        rejection_report.rejected_trials = rejected_trials;
        rejection_report.rejection_rate = rejection_rate;
        rejection_report.parameters = config.erplab_art_rej;
        rejection_report.timestamp = datetime('now');
        
        report_file = fullfile(config.dirs.quality_control, 'individual_reports', ...
            [subject_id '_erplab_art_rej_report.mat']);
        save(report_file, 'rejection_report');
        
        success = true;
        fprintf('  ERPLAB artifact rejection completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in ERPLAB artifact rejection %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_erplab_art_rej_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end