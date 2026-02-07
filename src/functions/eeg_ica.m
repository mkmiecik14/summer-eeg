function [success, EEG] = eeg_ica(subject_id, config)
    % EEG_ICA - Independent Component Analysis decomposition with space-efficient storage
    %
    % EEG_ICA performs Independent Component Analysis (ICA) decomposition on
    % preprocessed EEG data to separate neural sources from artifacts. Uses
    % extended Infomax algorithm with automatic rank calculation and innovative
    % space-efficient storage system that saves 95%+ disk space.
    %
    % Syntax: 
    %   [success, EEG] = eeg_ica(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'george')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.preprocessed - Preprocessed data directory
    %                .dirs.ica         - ICA weights output directory
    %                .naming           - File naming conventions
    %                Excel database path for bad channel information
    %
    % Outputs:
    %   success - Logical, true if ICA decomposition completed successfully
    %   EEG     - EEGLAB EEG structure with complete ICA decomposition
    %             (Note: Full dataset not saved, only lightweight weights)
    %
    % Processing Pipeline:
    %   1. Load 1Hz preprocessed data (optimal for ICA)
    %   2. Check for visually-inspected data variants (*vis-rej.set)
    %   3. Extract bad channel information from Excel database
    %   4. Interpolate bad channels using spherical interpolation
    %   5. Calculate theoretical data rank (channels - bad_channels - reference)
    %   6. Run extended Infomax ICA with computed rank constraint
    %   7. Save only ICA weights (95%+ disk space savings)
    %
    % ICA Algorithm:
    %   - Extended Infomax (pop_runica with 'extended', 1)
    %   - Automatic rank calculation prevents overfitting
    %   - PCA dimensionality reduction to theoretical rank
    %   - Interruptible processing for large datasets
    %
    % Data Rank Calculation:
    %   rank = n_channels - n_bad_channels - n_reference_channels
    %   Accounts for: interpolated channels, linked mastoid reference
    %   Prevents ICA convergence issues from rank deficiency
    %
    % Space-Efficient Storage:
    %   - Saves only ICA weights (~1-5 MB) vs full datasets (~100+ MB)
    %   - Preserves complete ICA functionality
    %   - Weights can be applied to any compatible dataset
    %   - Includes metadata for traceability and validation
    %
    % Examples:
    %   % Run ICA decomposition on preprocessed data
    %   config = default_config();
    %   [success, EEG] = eeg_ica('kramer', config);
    %
    %   % Check for processing success
    %   if success
    %       fprintf('ICA decomposition completed\n');
    %   end
    %
    %   % Later apply weights to different dataset
    %   [EEG_new, ~] = load_eeg_from_stage('kramer', 'preprocessed', config);
    %   EEG_new = load_ica_weights(EEG_new, 'kramer', config);
    %
    % Visually-Inspected Data:
    %   - Automatically detects *vis-rej.set files in preprocessed directory
    %   - Uses manually cleaned data if available
    %   - Preserves manual artifact rejection for ICA input
    %
    % Error Handling:
    %   - Comprehensive error logging to output/logs/error_logs/
    %   - Detailed error messages with subject identification
    %   - Processing continues with other subjects on individual failures
    %   - Error structures saved for debugging
    %
    % Notes:
    %   - Uses 1Hz preprocessed data (better for ICA convergence)
    %   - Requires channel location information for interpolation
    %   - ICA weights stored separately from full datasets
    %   - Memory-efficient approach suitable for large studies
    %   - Compatible with subsequent epoching and component rejection
    %
    % See also: pop_runica, pop_interp, save_ica_weights, load_ica_weights, eeg_prepro
    %
    % Author: Matt Kmiecik
    
    success = false;
    EEG = [];
    
    fprintf('=== ICA PROCESSING SUBJECT: %s ===\n', subject_id);
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
    end
    
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
        
        %% CALCULATE "THEORETICAL" RANK
        data_rank = EEG.nbchan - length(bad_channels) - 1; % -1 for linked mastoids
        
        %% RUN ICA
        fprintf('  Running ICA decomposition (rank=%d)...\n', data_rank);
        EEG = pop_runica(EEG, ...
            'icatype', 'runica', ...
            'extended', 1, ...
            'interrupt', 'on', ...
            'pca', data_rank);
        
        %% SAVE ICA WEIGHTS ONLY (SPACE-EFFICIENT)
        fprintf('  Saving ICA weights (lightweight)...\n');
        save_ica_weights(EEG, subject_id, config);
        
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