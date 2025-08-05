% FILE: src/functions/eeg_prepro.m (Updated for stage-based saving)

function [success, EEG_01Hz, EEG_1Hz] = eeg_prepro(subject_id, config)
    % PROCESS_SUBJECT_PREPROCESSING - Preprocess EEG data with stage-based saving
    
    success = false;
    EEG_01Hz = [];
    EEG_1Hz = [];
    
    fprintf('=== PREPROCESSING SUBJECT: %s ===\n', subject_id);
    
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
        
        %% PREPROCESSING STEPS (same as before)
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
        
        fprintf('  Removing DC offset...\n');
        EEG = pop_rmbase(EEG, [], []);
        
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