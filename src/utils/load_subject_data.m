% FILE: src/utils/load_subject_data.m

function [EEG, data_file] = load_subject_data(subject_id, data_type, config)
    % LOAD_SUBJECT_DATA - Load preprocessed data for a subject
    %
    % Standardized function for loading EEG data with pattern matching
    % to find the correct file.
    %
    % Syntax: [EEG, data_file] = load_subject_data(subject_id, data_type, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier
    %   data_type  - String, type of data ('prepro', '1Hz-prepro', '1Hz-ica', etc.)
    %   config     - Configuration structure
    %
    % Outputs:
    %   EEG       - Loaded EEG structure
    %   data_file - File information structure
    %
    % Example:
    %   [EEG, file] = load_subject_data('sub001', '1Hz-prepro', config);

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