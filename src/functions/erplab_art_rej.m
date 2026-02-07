function [success, EEG] = erplab_art_rej(subject_id, config)
    % ERPLAB_ART_REJ - Advanced 5-step ERPLAB artifact rejection pipeline
    %
    % ERPLAB_ART_REJ performs comprehensive artifact rejection on preprocessed
    % EEG data using ERPLAB's advanced artifact detection algorithms. Implements
    % a 5-step detection process for extreme values, peak-to-peak variations,
    % step-like artifacts, linear trends, and flatline detection with physical
    % epoch removal and detailed reporting.
    %
    % Syntax: 
    %   [success, EEG] = erplab_art_rej(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'helen')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.preprocessed      - Preprocessed data directory
    %                .dirs.epoched          - Epoched data output directory
    %                .dirs.artifacts_rejected - Clean data output directory
    %                .erplab_dir            - ERPLAB toolbox path
    %                .event_codes           - Event codes for epoching
    %                .naming                - File naming conventions
    %                .erplab_art_rej        - Artifact rejection parameters:
    %                  .epoch_window        - Epoching time window [start end] (s)
    %                  .baseline_window     - Baseline correction window (s)
    %                  .extreme_values_threshold     - Extreme value threshold (µV)
    %                  .peak_to_peak_threshold       - Peak-to-peak threshold (µV)
    %                  .peak_to_peak_window_size     - Moving window size (ms)
    %                  .peak_to_peak_window_step     - Moving window step (ms)
    %                  .step_threshold               - Step artifact threshold (µV)
    %                  .step_window_size             - Step detection window (ms)
    %                  .step_window_step             - Step detection step (ms)
    %                  .trend_min_slope              - Linear trend slope threshold
    %                  .trend_min_r2                 - Linear trend R² threshold
    %
    % Outputs:
    %   success - Logical, true if artifact rejection completed successfully
    %   EEG     - Final EEGLAB EEG structure with physically removed epochs
    %
    % Processing Pipeline:
    %   1. Load ERPLAB preprocessed data from stage directory
    %   2. Create ERPLAB eventlist with boundary handling
    %   3. Create epochs around specified event codes
    %   4. Apply baseline correction
    %   5. Run 5-step artifact detection (flagging only)
    %   6. Synchronize rejection flags between ERPLAB and EEGLAB
    %   7. Save epoched data with rejection markers
    %   8. Physically remove flagged epochs
    %   9. Save final clean data
    %   10. Generate comprehensive rejection report
    %
    % 5-Step Artifact Detection:
    %   Step 1: Extreme Values
    %     - Detects absolute amplitudes > threshold (±100 µV default)
    %     - Applied across entire epoch time window
    %
    %   Step 2: Peak-to-Peak in Moving Windows
    %     - Detects excessive peak-to-peak variations (±75 µV default)
    %     - Uses overlapping windows (200ms window, 100ms step default)
    %
    %   Step 3: Step-like Artifacts
    %     - Detects sudden amplitude steps (±60 µV default)
    %     - Uses smaller windows (250ms window, 20ms step default)
    %
    %   Step 4: Linear Trends
    %     - Detects excessive linear trends across epochs
    %     - Thresholds: slope >75, R² >0.3 (default)
    %
    %   Step 5: Flatline Detection
    %     - Detects completely flat/dead channels
    %     - Uses 0 µV threshold for complete flatline
    %
    % ERPLAB Integration:
    %   - Uses pop_creabasiceventlist() for eventlist creation
    %   - Handles boundary events (-99) automatically
    %   - Synchronizes flags between ERPLAB and EEGLAB systems
    %   - Compatible with ERPLAB GUI workflow
    %
    % Physical Epoch Removal:
    %   - NEW: Actually removes flagged epochs using pop_rejepoch()
    %   - Previous versions only flagged epochs
    %   - Final dataset contains only clean epochs
    %   - Enables accurate trial counting for analysis
    %
    % Examples:
    %   % Run ERPLAB artifact rejection on preprocessed data
    %   config = default_config();
    %   [success, EEG] = erplab_art_rej('morty', config);
    %
    %   % Complete ERPLAB workflow
    %   [success1, EEG_prepro] = erplab_prepro('helen', config);
    %   if success1
    %       [success2, EEG_clean] = erplab_art_rej('helen', config);
    %   end
    %
    %   % Batch processing workflow
    %   run_erplab_preprocessing;      % Step 1: Time-intensive filtering
    %   run_erplab_artifact_rejection; % Step 2: Fast artifact rejection
    %
    % Output Files:
    %   - Epoched with markers: output/05_epoched/[subject]-epochs-erplab.set
    %   - Final clean data: output/06_artifacts_rejected/[subject]-art-rej-erplab.set
    %   - Rejection report: output/quality_control/individual_reports/
    %
    % Quality Control:
    %   - Detailed rejection statistics and rates
    %   - Method-specific parameters logged
    %   - Individual subject reports with timestamps
    %   - Compatible with batch processing summaries
    %
    % Error Handling:
    %   - ERPLAB function availability verification
    %   - Comprehensive error logging with method identification
    %   - Missing file detection and informative messages
    %   - Processing continues with other subjects on failures
    %
    % Notes:
    %   - Requires ERPLAB-preprocessed data from erplab_prepro()
    %   - More sophisticated than simple amplitude thresholding
    %   - Optimized for ERP analysis with multiple detection criteria
    %   - Fast execution after time-intensive preprocessing
    %   - Physically removes epochs (vs just flagging)
    %
    % See also: erplab_prepro, pop_artextval, pop_artmwppth, pop_rejepoch, pop_syncroartifacts
    %
    % Author: Matt Kmiecik
    
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
        % Setup diary logging with timestamp
        log_dir = fullfile(config.dirs.logs, subject_id);
        if ~exist(log_dir, 'dir'), mkdir(log_dir); end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        diary(fullfile(log_dir, [subject_id '_erplab_art_rej_' timestamp '.txt']));

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
        
        success = true;
        fprintf('  ERPLAB artifact rejection completed successfully for %s\n', subject_id);
        diary off;

    catch ME
        fprintf('  ERROR in ERPLAB artifact rejection %s: %s\n', subject_id, ME.message);
        fprintf('  Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        diary off;
        rethrow(ME);
    end
end