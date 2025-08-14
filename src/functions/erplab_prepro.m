% FILE: src/functions/erplab_prepro.m

function [success, EEG] = erplab_prepro(subject_id, config)
    % ERPLAB_PREPRO - ERPLAB-based preprocessing up to baseline correction
    
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
        
        %% SAVE PREPROCESSED DATA TO 02_PREPROCESSED
        fprintf('  Saving preprocessed data...\n');
        prepro_filename = sprintf(config.naming.preprocessed_erplab, subject_id);
        EEG = pop_saveset(EEG, 'filename', [prepro_filename '.set'], ...
            'filepath', config.dirs.preprocessed);
        
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