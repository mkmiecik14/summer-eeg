function [EEG, data_file] = load_subject_data(subject_id, data_type, config)
    % LOAD_SUBJECT_DATA - Load EEG data using flexible pattern matching
    %
    % LOAD_SUBJECT_DATA provides a flexible interface for loading EEG datasets
    % using pattern-based file discovery. This legacy function supports older
    % naming conventions and provides wildcard matching capabilities for
    % datasets that don't follow strict stage-based naming.
    %
    % Syntax: 
    %   [EEG, data_file] = load_subject_data(subject_id, data_type, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'helen')
    %   data_type  - String, data type pattern for file matching:
    %                'prepro'     - Standard preprocessed data
    %                '1Hz-prepro' - 1Hz high-pass filtered preprocessed data
    %                '1Hz-ica'    - 1Hz data with ICA decomposition
    %                'ica'        - ICA decomposed data
    %                'epochs'     - Epoched data
    %                'art-rej'    - Artifact rejected data
    %                Custom patterns supported with wildcards
    %   config     - Configuration structure from default_config() containing:
    %                .output_dir - Main output directory for data search
    %
    % Outputs:
    %   EEG       - EEGLAB EEG structure containing loaded dataset
    %   data_file - File information structure with .name, .folder, .date fields
    %
    % File Discovery:
    %   Uses pattern matching: [subject_id]*[data_type].set
    %   Searches in: config.output_dir (recursive search across subdirectories)
    %   Example patterns:
    %     'elaine*prepro.set'     -> elaine-prepro.set
    %     'jerry*1Hz-ica.set'    -> jerry-1Hz-ica.set
    %
    % Examples:
    %   % Load legacy preprocessed data
    %   config = default_config();
    %   [EEG, file] = load_subject_data('george', 'prepro', config);
    %
    %   % Load 1Hz filtered ICA data
    %   [EEG, file] = load_subject_data('kramer', '1Hz-ica', config);
    %
    %   % Load epoched data
    %   [EEG, file] = load_subject_data('newman', 'epochs', config);
    %
    % Error Handling:
    %   - Throws error if no files match the search pattern
    %   - Warns and uses first file if multiple files match
    %   - Provides full search pattern in error messages
    %
    % Notes:
    %   - Legacy function maintained for backward compatibility
    %   - For new code, prefer load_eeg_from_stage() with stage-based loading
    %   - Uses wildcard matching which is more flexible but less structured
    %   - Prints loaded filename for verification
    %   - Pattern matching is case-sensitive on Unix systems
    %
    % See also: load_eeg_from_stage, pop_loadset, default_config, dir
    %
    % Author: Matt Kmiecik

    % Create search pattern
    pattern = fullfile(config.output_dir, [subject_id '*' data_type '.set']);
    data_file = dir(pattern);
    
    if isempty(data_file)
        error('Data file not found: %s', pattern);
    end
    
    if length(data_file) > 1
        warning('Multiple files found for pattern %s, using first one', pattern);
        data_file = data_file(1);
    end
    
    % Load the dataset
    EEG = pop_loadset('filename', data_file.name, 'filepath', data_file.folder);
    
    fprintf('    Loaded: %s\n', data_file.name);
end