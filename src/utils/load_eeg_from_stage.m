function [EEG, data_file] = load_eeg_from_stage(subject_id, stage, config, variant)
    % LOAD_EEG_FROM_STAGE - Load EEG datasets from standardized processing stages
    %
    % LOAD_EEG_FROM_STAGE provides a unified interface for loading EEG data
    % from any processing stage using the project's standardized directory
    % structure and naming conventions. Supports multiple variants and robust
    % file discovery with detailed error reporting.
    %
    % Syntax: 
    %   [EEG, data_file] = load_eeg_from_stage(subject_id, stage, config)
    %   [EEG, data_file] = load_eeg_from_stage(subject_id, stage, config, variant)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'george')
    %   stage      - String, processing stage to load from:
    %                'preprocessed'        - Filtered, re-referenced data
    %                'ica'                 - ICA decomposition results  
    %                'components_rejected' - Data after component removal
    %                'epoched'             - Segmented data around events
    %                'artifacts_rejected'  - Final clean epochs
    %                'final'               - Analysis-ready datasets
    %   config     - Configuration structure from default_config() containing:
    %                .dirs   - Directory paths for each stage
    %                .naming - Filename patterns for each stage
    %   variant    - String, optional data variant:
    %                '1Hz'  - 1Hz high-pass filtered version (preprocessed only)
    %                ''     - Default 0.1Hz version (default)
    %
    % Outputs:
    %   EEG       - EEGLAB EEG structure containing loaded dataset
    %   data_file - File information structure with .name, .folder, .date fields
    %
    % Stage Directory Mapping:
    %   preprocessed        -> output/02_preprocessed/
    %   ica                 -> output/03_ica/
    %   components_rejected -> output/04_components_rejected/
    %   epoched             -> output/05_epoched/
    %   artifacts_rejected  -> output/06_artifacts_rejected/
    %   final               -> output/07_final/
    %
    % Examples:
    %   % Load standard preprocessed data (0.1Hz)
    %   config = default_config();
    %   [EEG, file] = load_eeg_from_stage('newman', 'preprocessed', config);
    %
    %   % Load 1Hz variant of preprocessed data
    %   [EEG, file] = load_eeg_from_stage('frank', 'preprocessed', config, '1Hz');
    %
    %   % Load epoched data for analysis
    %   [EEG, file] = load_eeg_from_stage('estelle', 'epoched', config);
    %
    % Error Handling:
    %   - Throws error if stage is not recognized
    %   - Throws error if no files match the expected pattern
    %   - Warns and uses first file if multiple files match pattern
    %   - Provides detailed file path information in error messages
    %
    % Notes:
    %   - Uses pop_loadset() for EEGLAB compatibility
    %   - Automatically constructs file paths using config naming conventions
    %   - Supports variant naming for filtered data versions
    %   - Prints loaded filename for verification
    %   - File discovery is case-sensitive on Unix systems
    %
    % See also: pop_loadset, save_eeg_to_stage, default_config, review_eeg_simple
    %
    % Author: Matt Kmiecik

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