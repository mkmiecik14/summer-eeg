function [success, EEG_01Hz, EEG_1Hz] = eeg_prepro(subject_id, config)
    % EEG_PREPRO - Comprehensive EEGLAB-based EEG preprocessing pipeline
    %
    % EEG_PREPRO performs complete EEG preprocessing from raw .bdf files through
    % filtered, re-referenced, and cleaned datasets. Creates both 0.1Hz and 1Hz
    % high-pass filtered variants optimized for different analysis needs with
    % integrated quality control and stage-based output organization.
    %
    % Syntax: 
    %   [success, EEG_01Hz, EEG_1Hz] = eeg_prepro(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'newman')
    %   config     - Configuration structure from default_config() containing:
    %                .data_dir            - Raw data directory path
    %                .doc_dir            - Channel info and documentation path
    %                .dirs               - Stage-based output directories
    %                .external_channels  - Channels to remove (EXG1-8)
    %                .channels_to_keep   - Channels to retain (A1-32, B1-32)
    %                .sampling_rate      - Target sampling rate (Hz)
    %                .reference_channels - Re-reference channel indices
    %                .highpass_01hz      - 0.1Hz filter cutoff
    %                .highpass_1hz       - 1Hz filter cutoff
    %                .cleanline          - Line noise removal parameters
    %                .enable_quality_control - QC assessment toggle
    %
    % Outputs:
    %   success   - Logical, true if preprocessing completed successfully
    %   EEG_01Hz  - EEGLAB EEG structure with 0.1Hz high-pass filter
    %   EEG_1Hz   - EEGLAB EEG structure with 1Hz high-pass filter
    %
    % Processing Pipeline:
    %   1. Load raw .bdf data using BIOSIG toolbox
    %   2. Remove external channels (EXG1-8)
    %   3. Select standard 64-channel EEG montage (A1-32, B1-32)
    %   4. Configure channel locations and reference settings
    %   5. Downsample to target sampling rate (256 Hz)
    %   6. Re-reference to linked mastoids (keep reference)
    %   7. Apply dual high-pass filtering (0.1Hz and 1Hz)
    %   8. Remove 60Hz line noise using CleanLine
    %   9. Save both filtered versions to stage directories
    %   10. Run quality control assessment (optional)
    %
    % Filter Variants:
    %   0.1Hz High-pass: Optimal for epoching and time-domain analysis
    %   1Hz High-pass:   Optimal for ICA decomposition and source separation
    %
    % Channel Configuration:
    %   - Uses standardized 64-channel montage (10-20 system)
    %   - Loads channel locations from chan_locs_nose_along_fixed.mat
    %   - Loads channel info from chan_info_nose_along_fixed.mat
    %   - Reference set to Fp1, re-referenced to average mastoids
    %
    % Data Quality:
    %   - Automatic quality control with comprehensive metrics
    %   - Visual quality reports (if config.generate_reports = true)
    %   - Quality scores and problematic channel detection
    %   - Reports saved to quality_control/individual_reports/
    %
    % Examples:
    %   % Run complete preprocessing pipeline
    %   config = default_config();
    %   [success, EEG_01Hz, EEG_1Hz] = eeg_prepro('frank', config);
    %
    %   % Check processing success and access results
    %   if success
    %       fprintf('Preprocessing completed\n');
    %       fprintf('0.1Hz data: %d channels, %.1f Hz\n', EEG_01Hz.nbchan, EEG_01Hz.srate);
    %       fprintf('1Hz data: %d channels, %.1f Hz\n', EEG_1Hz.nbchan, EEG_1Hz.srate);
    %   end
    %
    % Error Handling:
    %   - Comprehensive error logging to output/logs/error_logs/
    %   - Missing file detection with informative error messages
    %   - Processing continues with other subjects on individual failures
    %   - Error structures saved with timestamps for debugging
    %
    % File Requirements:
    %   - Raw data: [subject_id].bdf in data/ directory
    %   - Channel locations: doc/chan_locs_nose_along_fixed.mat
    %   - Channel info: doc/chan_info_nose_along_fixed.mat
    %   - Output directories created automatically if needed
    %
    % Notes:
    %   - Creates both 0.1Hz and 1Hz variants for different analysis needs
    %   - Uses BIOSIG toolbox for .bdf file loading
    %   - Applies consistent preprocessing across all subjects
    %   - Stage-based organization for systematic workflow
    %   - Memory-efficient with automatic cleanup
    %
    % See also: pop_biosig, pop_reref, apply_cleanline_to_eeg, save_eeg_to_stage, run_quality_control
    %
    % Author: Matt Kmiecik
    
    success = false;
    EEG_01Hz = [];
    EEG_1Hz = [];
    
    fprintf('=== PREPROCESSING SUBJECT: %s ===\n', subject_id);
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
    end
    
    try
        % Ensure output directories exist
        if config.create_directories
            setup_output_directories(config);
        end
        
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
        
        %% PREPROCESSING STEPS
        fprintf('  Removing external channels...\n');
        EEG = pop_select(EEG, 'rmchannel', config.external_channels);
        
        if EEG.nbchan > 64
            fprintf('  Selecting %d channels...\n', length(config.channels_to_keep));
            EEG = pop_select(EEG, 'channel', config.channels_to_keep);
        else
            fprintf('  Only 64 channels detected; keeping all...\n');
        end
        
        fprintf('  Configuring channel locations...\n');
        load(fullfile(config.doc_dir, 'chan_info_nose_along_fixed.mat'));
        load(fullfile(config.doc_dir, 'chan_locs_nose_along_fixed.mat'));
        EEG.chaninfo = chan_info;
        EEG.chanlocs = chan_locs;
        EEG = pop_chanedit(EEG, 'setref', {'1:64' 'Fp1'});
        
        fprintf('  Downsampling to %d Hz...\n', config.sampling_rate);
        EEG = pop_resample(EEG, config.sampling_rate);
        
        fprintf('  Re-referencing to linked mastoids...\n');
        EEG = pop_reref(EEG, config.reference_channels, 'keepref', 'on');
        
        %% FILTERING
        fprintf('  Applying 0.1Hz highpass filter...\n');
        EEG_01Hz = pop_eegfiltnew(EEG, 'locutoff', config.highpass_01hz, 'plotfreqz', 0);
        
        fprintf('  Applying 1Hz highpass filter...\n');
        EEG_1Hz = pop_eegfiltnew(EEG, 'locutoff', config.highpass_1hz, 'plotfreqz', 0);
        
        %% CLEANLINE
        fprintf('  Applying cleanline to 0.1Hz data...\n');
        EEG_01Hz = apply_cleanline_to_eeg(EEG_01Hz, config);
        
        fprintf('  Applying cleanline to 1Hz data...\n');
        EEG_1Hz = apply_cleanline_to_eeg(EEG_1Hz, config);
        
        %% SAVE TO APPROPRIATE STAGE DIRECTORIES
        fprintf('  Saving preprocessed datasets...\n');
        
        % Save 0.1Hz data to preprocessed stage
        EEG_01Hz = save_eeg_to_stage(EEG_01Hz, subject_id, 'preprocessed', config);
        
        % Save 1Hz data to preprocessed stage with variant
        EEG_1Hz = save_eeg_to_stage(EEG_1Hz, subject_id, 'preprocessed', config, '1Hz');
        
        %% QUALITY CONTROL (save to QC directory)
        if config.enable_quality_control
            fprintf('  Running quality control...\n');
            [EEG_01Hz, quality_report] = run_quality_control(EEG_01Hz, subject_id, config);
            
            % Save quality report to QC directory
            qc_file = fullfile(config.dirs.quality_control, 'individual_reports', ...
                [subject_id '_preprocessing_quality.mat']);
            save(qc_file, 'quality_report');
        end
        
        success = true;
        fprintf('  Preprocessing completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in preprocessing %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_preprocessing_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end