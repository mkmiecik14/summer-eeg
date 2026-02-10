function [success, EEG] = erplab_prepro(subject_id, config)
    % ERPLAB_PREPRO - ERPLAB-compatible preprocessing pipeline up to baseline correction
    %
    % ERPLAB_PREPRO performs EEG preprocessing using ERPLAB-compatible workflow
    % from raw .bdf files through filtered and re-referenced data. Creates
    % preprocessed datasets optimized for subsequent ERPLAB artifact rejection
    % with time-efficient filtering and standardized channel configuration.
    %
    % Syntax: 
    %   [success, EEG] = erplab_prepro(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'estelle')
    %   config     - Configuration structure from default_config() containing:
    %                .data_dir                    - Raw data directory path
    %                .doc_dir                    - Channel documentation path
    %                .dirs.preprocessed          - Preprocessed output directory
    %                .erplab_dir                 - ERPLAB toolbox path
    %                .external_channels          - Channels to remove (EXG1-8)
    %                .channels_to_keep           - Standard EEG channels (A1-32, B1-32)
    %                .reference_channels         - Mastoid reference indices
    %                .erplab_art_rej.resample_rate   - Target sampling rate
    %                .erplab_art_rej.highpass_filter - High-pass cutoff (Hz)
    %                .erplab_art_rej.lowpass_filter  - Low-pass cutoff (Hz)
    %                .naming.preprocessed_erplab - ERPLAB naming convention
    %
    % Outputs:
    %   success - Logical, true if preprocessing completed successfully
    %   EEG     - EEGLAB EEG structure with ERPLAB-compatible preprocessing
    %
    % Processing Pipeline:
    %   1. Load raw .bdf data using BIOSIG toolbox
    %   2. Remove external channels (EXG1-8)
    %   3. Select standard 64-channel EEG montage
    %   4. Configure channel locations and reference settings
    %   5. Resample to target rate (typically 256 Hz)
    %   6. Apply band-pass filter (0.01-30 Hz default)
    %   7. Re-reference to average mastoids
    %   8. Save with ERPLAB naming convention
    %
    % ERPLAB Integration:
    %   - Automatically adds ERPLAB to MATLAB path
    %   - Verifies ERPLAB function availability
    %   - Uses ERPLAB-compatible data format
    %   - Prepares data for ERPLAB artifact rejection workflow
    %   - Saves with erplab suffix for identification
    %
    % Filter Settings:
    %   - High-pass: 0.01 Hz (removes slow drifts, preserves ERPs)
    %   - Low-pass: 30 Hz (reduces high-frequency noise)
    %   - Time-efficient filtering optimized for ERPLAB workflow
    %   - Single filtering pass (vs dual 0.1Hz/1Hz in EEGLAB pipeline)
    %
    % Channel Configuration:
    %   - Standard 64-channel 10-20 system montage
    %   - Removes external channels (EXG1-8) automatically
    %   - Loads standardized channel locations and info
    %   - Sets reference to Fp1, re-references to average mastoids
    %
    % Examples:
    %   % Run ERPLAB preprocessing only
    %   config = default_config();
    %   [success, EEG] = erplab_prepro('morty', config);
    %
    %   % Follow with ERPLAB artifact rejection
    %   if success
    %       [success_art, EEG_clean] = erplab_art_rej('morty', config);
    %   end
    %
    %   % Split workflow for time efficiency
    %   run_erplab_preprocessing;      % Batch preprocessing (time-intensive)
    %   run_erplab_artifact_rejection; % Batch artifact rejection (fast)
    %
    % Error Handling:
    %   - Comprehensive try-catch with ERPLAB-specific error logging
    %   - ERPLAB function availability checking
    %   - Missing file detection and informative error messages
    %   - Error files saved to: output/logs/error_logs/
    %
    % Performance:
    %   - Time-intensive filtering step separated from artifact rejection
    %   - Enables split workflow for computational efficiency
    %   - Single filter pass reduces processing time
    %   - Optimized for batch processing scenarios
    %
    % Notes:
    %   - Alternative to eeg_prepro() using ERPLAB workflow
    %   - Designed for time-efficient split processing
    %   - Creates single filtered variant (not dual like EEGLAB)
    %   - Compatible with erplab_art_rej() for subsequent processing
    %   - Requires ERPLAB plugin installation in EEGLAB
    %
    % See also: erplab_art_rej, eeg_prepro, pop_biosig, pop_reref, run_erplab_preprocessing
    %
    % Author: Matt Kmiecik
    
    success = false;
    EEG = [];
    
    fprintf('=== ERPLAB PREPROCESSING: %s ===\n', subject_id);
    
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
        diary(fullfile(log_dir, [subject_id '_erplab_prepro_' timestamp '.txt']));

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
        EEG = pop_reref(EEG, config.reference_channels, 'keepref', 'on');
        
        %% SAVE PREPROCESSED DATA TO 01_PREPROCESSED
        fprintf('  Saving preprocessed data...\n');
        prepro_filename = sprintf(config.naming.preprocessed_erplab, subject_id);
        EEG = pop_saveset(EEG, 'filename', [prepro_filename '.set'], ...
            'filepath', config.dirs.preprocessed);
        
        success = true;
        fprintf('  ERPLAB preprocessing completed successfully for %s\n', subject_id);
        diary off;

    catch ME
        fprintf('  ERROR in ERPLAB preprocessing %s: %s\n', subject_id, ME.message);
        fprintf('  Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        diary off;
        rethrow(ME);
    end
end