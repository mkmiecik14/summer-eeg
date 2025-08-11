% FILE: src/functions/eeg_prepro_art_rej.m

function [success, EEG] = eeg_prepro_art_rej(subject_id, config)
    % EEG_PREPRO_ART_REJ - ERPLAB-based preprocessing and artifact rejection
    
    success = false;
    EEG = [];
    
    fprintf('=== ERPLAB PREPROCESSING & ARTIFACT REJECTION: %s ===\n', subject_id);
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
    end
    Can 
    try
        %% LOAD RAW DATA
        fprintf('  Loading raw data...\n');
        this_ss_path = dir(fullfile(config.data_dir, strcat(subject_id, '.bdf')));
        
        if isempty(this_ss_path)
            error('Data file not found for subject %s', subject_id);
        end
        
        EEG = pop_biosig(...
            fullfile(this_ss_path.folder, this_ss_path.name),...
            'ref', [1] ,...
            'refoptions',{'keepref','on'},...
            'importannot', 'off',...
            'bdfeventmode', 6);

        %% REMOVING EXTERNAL CHANNELS
        fprintf('  Removing external channels...\n');
        EEG = pop_select(EEG, 'rmchannel', config.external_channels);
        
        if EEG.nbchan > 64
            fprintf('  Selecting %d channels...\n', length(config.channels_to_keep));
            EEG = pop_select(EEG, 'channel', config.channels_to_keep);
        else
            fprintf('  Only 64 channels detected; keeping all...\n');
        end
        
        %% CONFIGURING CHANNEL LOCATIONS
        fprintf('  Configuring channel locations...\n');
        load(fullfile(config.doc_dir, 'chan_info_nose_along_fixed.mat'));
        load(fullfile(config.doc_dir, 'chan_locs_nose_along_fixed.mat'));
        EEG.chaninfo = chan_info;
        EEG.chanlocs = chan_locs;
        EEG = pop_chanedit(EEG, 'setref', {'1:64' 'Fp1'});
        
        %% RESAMPLE TO 256 Hz
        fprintf('  Resampling to %d Hz...\n', config.erplab_art_rej.resample_rate);
        if EEG.srate ~= config.erplab_art_rej.resample_rate
            EEG = pop_resample(EEG, config.erplab_art_rej.resample_rate);
        end
        
        %% HIGH PASS FILTER AT 0.01 Hz; LOWPASS FILTER AT 30 Hz
        fprintf('  Applying filters (%.2f - %d Hz)...\n', ...
            config.erplab_art_rej.highpass_filter, ...
            config.erplab_art_rej.lowpass_filter);
        EEG = pop_eegfiltnew(EEG, 'locutoff', config.erplab_art_rej.highpass_filter, ...
            'hicutoff', config.erplab_art_rej.lowpass_filter);
        
        %% REREFERENCE TO AVERAGE MASTOID
        fprintf('  Re-referencing to average mastoid...\n');
        EEG = pop_reref(EEG, config.reference_channels);

        %% CREATE BASIC EVENTLIST FOR ERPLAB
        fprintf('  Creating ERPLAB eventlist...\n');
        EEG = pop_creabasiceventlist(EEG);
        
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
        for ext_ch = config.external_channels
            ch_idx = find(strcmp({EEG.chanlocs.labels}, ext_ch));
            if ~isempty(ch_idx)
                eeg_channels(eeg_channels == ch_idx) = [];
            end
        end
        
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
        
        %% SAVE ARTIFACT REJECTED DATA
        fprintf('  Saving artifact-rejected data...\n');
        art_rej_filename = sprintf(config.naming.artifacts_rejected_erplab, subject_id);
        EEG = pop_saveset(EEG, 'filename', [art_rej_filename '.set'], ...
            'filepath', config.dirs.artifacts_rejected);
        
        %% GENERATE ARTIFACT REJECTION REPORT
        initial_trials = EEG.trials;
        rejected_trials = sum(EEG.reject.rejmanual);
        final_trials = initial_trials - rejected_trials;
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
        fprintf('  ERPLAB preprocessing completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in ERPLAB preprocessing %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_erplab_prepro_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end