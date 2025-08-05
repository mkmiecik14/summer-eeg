% FILE: src/utils/load_eeg_from_stage.m

function [EEG, data_file] = load_eeg_from_stage(subject_id, stage, config, variant)
    % LOAD_EEG_FROM_STAGE - Load EEG data from specific processing stage
    %
    % Loads EEG data from the appropriate stage directory using standardized
    % naming conventions.
    %
    % Syntax: [EEG, data_file] = load_eeg_from_stage(subject_id, stage, config, variant)
    %
    % Inputs:
    %   subject_id - String, subject identifier
    %   stage      - String, processing stage to load from
    %   config     - Configuration structure
    %   variant    - String, optional variant (e.g., '1Hz')
    %
    % Outputs:
    %   EEG       - Loaded EEG structure
    %   data_file - File information structure
    %
    % Examples:
    %   [EEG, file] = load_eeg_from_stage('sub001', 'preprocessed', config);
    %   [EEG, file] = load_eeg_from_stage('sub001', 'preprocessed', config, '1Hz');

    if nargin < 4
        variant = '';
    end
    
    % Determine source directory and filename pattern based on stage
    switch stage
        case 'preprocessed'
            source_dir = config.dirs.preprocessed;
            if strcmp(variant, '1Hz')
                pattern = sprintf([config.naming.preprocessed_1hz '.set'], subject_id);
            else
                pattern = sprintf([config.naming.preprocessed_01hz '.set'], subject_id);
            end
        case 'ica'
            source_dir = config.dirs.ica;
            pattern = sprintf([config.naming.ica '.set'], subject_id);
        case 'components_rejected'
            source_dir = config.dirs.components_rejected;
            pattern = sprintf([config.naming.components_rejected '.set'], subject_id);
        case 'epoched'
            source_dir = config.dirs.epoched;
            pattern = sprintf([config.naming.epoched '.set'], subject_id);
        case 'artifacts_rejected'
            source_dir = config.dirs.artifacts_rejected;
            pattern = sprintf([config.naming.artifacts_rejected '.set'], subject_id);
        case 'final'
            source_dir = config.dirs.final;
            pattern = sprintf([config.naming.final '.set'], subject_id);
        otherwise
            error('Unknown processing stage: %s', stage);
    end
    
    % Add variant to pattern if specified (for non-preprocessed stages)
    if ~isempty(variant) && ~strcmp(stage, 'preprocessed')
        pattern = strrep(pattern, '.set', ['-' variant '.set']);
    end
    
    % Find the file
    data_file = dir(fullfile(source_dir, pattern));
    
    if isempty(data_file)
        error('Data file not found: %s', fullfile(source_dir, pattern));
    end
    
    if length(data_file) > 1
        warning('Multiple files found for pattern %s, using first one', pattern);
        data_file = data_file(1);
    end
    
    % Load the dataset
    EEG = pop_loadset('filename', data_file.name, 'filepath', data_file.folder);
    
    fprintf('    Loaded from %s: %s\n', stage, data_file.name);
end