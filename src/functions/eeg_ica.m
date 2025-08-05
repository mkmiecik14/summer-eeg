% FILE: src/functions/eeg_ica.m (Updated for stage-based loading/saving)

function [success, EEG] = eeg_ica(subject_id, config)
    % EEG_ICA - ICA processing with stage-based organization
    
    success = false;
    EEG = [];
    
    fprintf('=== ICA PROCESSING SUBJECT: %s ===\n', subject_id);
    
    try
        %% LOAD PREPROCESSED DATA FROM STAGE DIRECTORY
        fprintf('  Loading 1Hz preprocessed data...\n');
        [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config, '1Hz');
        
        %% CHECK FOR VISUALLY REJECTED DATA
        % Look for manually cleaned data first
        vis_rej_pattern = [subject_id '*vis-rej.set'];
        vis_rej_files = dir(fullfile(config.dirs.preprocessed, vis_rej_pattern));
        
        if ~isempty(vis_rej_files)
            fprintf('  Loading visually inspected data...\n');
            EEG = pop_loadset('filename', vis_rej_files(1).name, ...
                'filepath', vis_rej_files(1).folder);
        end
        
        %% GET BAD CHANNELS
        bad_channels = get_bad_channels_from_excel(subject_id, config);
        
        %% INTERPOLATE BAD CHANNELS
        if ~isempty(bad_channels)
            fprintf('  Interpolating %d bad channels...\n', length(bad_channels));
            EEG = pop_interp(EEG, bad_channels, 'spherical');
        else
            fprintf('  No bad channels detected\n');
        end
        
        %% CALCULATE RANK
        data_rank = EEG.nbchan - length(bad_channels) - 1; % -1 for linked mastoids
        
        %% CHECK RANK DEFICIENCY
        if data_rank ~= rank(double(EEG.data))
            fprintf('  WARNING: Subject %s is rank deficient, skipping ICA\n', subject_id);
            return;
        end
        
        %% RUN ICA
        fprintf('  Running ICA decomposition (rank=%d)...\n', data_rank);
        EEG = pop_runica(EEG, ...
            'icatype', 'runica', ...
            'extended', 1, ...
            'interrupt', 'on', ...
            'pca', data_rank);
        
        %% SAVE TO ICA STAGE DIRECTORY
        fprintf('  Saving ICA dataset...\n');
        EEG = save_eeg_to_stage(EEG, subject_id, 'ica', config);
        
        success = true;
        fprintf('  ICA completed successfully for %s\n', subject_id);
        
    catch ME
        fprintf('  ERROR in ICA %s: %s\n', subject_id, ME.message);
        
        % Save error to logs directory
        error_file = fullfile(config.dirs.logs, 'error_logs', ...
            [subject_id '_ica_error.mat']);
        save(error_file, 'ME');
        
        rethrow(ME);
    end
end