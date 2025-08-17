function EEG = save_eeg_to_stage(EEG, subject_id, stage, config, variant)
    % SAVE_EEG_TO_STAGE - Save EEG data using stage-based directory organization
    %
    % SAVE_EEG_TO_STAGE saves EEG datasets to the appropriate processing stage
    % directory using standardized naming conventions and directory structure.
    % Automatically handles directory creation, filename generation, and
    % workspace management for the stage-based processing pipeline.
    %
    % Syntax: 
    %   EEG = save_eeg_to_stage(EEG, subject_id, stage, config)
    %   EEG = save_eeg_to_stage(EEG, subject_id, stage, config, variant)
    %
    % Inputs:
    %   EEG        - EEGLAB EEG structure to save
    %   subject_id - String, subject identifier (e.g., 'kramer')
    %   stage      - String, target processing stage:
    %                'preprocessed'        - Filtered, re-referenced data
    %                'ica'                 - ICA decomposition results
    %                'components_rejected' - Data after component removal
    %                'epoched'             - Segmented data around events
    %                'artifacts_rejected'  - Final clean epochs
    %                'final'               - Analysis-ready datasets
    %   config     - Configuration structure from default_config() containing:
    %                .dirs   - Directory paths for each stage
    %                .naming - Filename patterns for each stage
    %   variant    - String, optional data variant suffix:
    %                '1Hz' - 1Hz high-pass filtered version (preprocessed only)
    %                ''    - Default version (default)
    %
    % Outputs:
    %   EEG - Updated EEGLAB EEG structure with:
    %         .setname updated to match stage naming convention
    %         .filename and .filepath set to save location
    %         Validated by eeg_checkset()
    %
    % Stage Directory Mapping:
    %   preprocessed        -> output/02_preprocessed/
    %   ica                 -> output/03_ica/
    %   components_rejected -> output/04_components_rejected/
    %   epoched             -> output/05_epoched/
    %   artifacts_rejected  -> output/06_artifacts_rejected/
    %   final               -> output/07_final/
    %
    % Naming Convention Examples:
    %   Standard: 'frank-prepro-01hz.set'
    %   Variant:  'estelle-prepro-1hz.set'
    %   ICA:      'morty-ica.set'
    %   Epoched:  'helen-epochs.set'
    %
    % Examples:
    %   % Save standard preprocessed data (0.1Hz)
    %   config = default_config();
    %   EEG = save_eeg_to_stage(EEG, 'elaine', 'preprocessed', config);
    %
    %   % Save 1Hz variant of preprocessed data
    %   EEG = save_eeg_to_stage(EEG, 'jerry', 'preprocessed', config, '1Hz');
    %
    %   % Save ICA results
    %   EEG = save_eeg_to_stage(EEG, 'george', 'ica', config);
    %
    % Workspace Integration:
    %   - Automatically updates ALLEEG workspace if present
    %   - Uses eeg_store() for proper EEGLAB dataset management
    %   - Maintains CURRENTSET index for GUI compatibility
    %   - Safe for both batch processing and interactive use
    %
    % Notes:
    %   - Creates output directories automatically if they don't exist
    %   - Prints stage and filename for verification
    %   - Variant naming only applies to non-preprocessed stages as suffix
    %   - Uses config naming patterns for consistent file organization
    %   - Preferred method for pipeline-based EEG data saving
    %
    % See also: save_eeg_dataset, pop_saveset, load_eeg_from_stage, default_config
    %
    % Author: Matt Kmiecik

    if nargin < 5
        variant = '';
    end
    
    % Determine output directory based on stage
    switch stage
        case 'preprocessed'
            output_dir = config.dirs.preprocessed;
            if strcmp(variant, '1Hz')
                dataset_name = sprintf(config.naming.preprocessed_1hz, subject_id);
            else
                dataset_name = sprintf(config.naming.preprocessed_01hz, subject_id);
            end
        case 'ica'
            output_dir = config.dirs.ica;
            dataset_name = sprintf(config.naming.ica, subject_id);
        case 'components_rejected'
            output_dir = config.dirs.components_rejected;
            dataset_name = sprintf(config.naming.components_rejected, subject_id);
        case 'epoched'
            output_dir = config.dirs.epoched;
            dataset_name = sprintf(config.naming.epoched, subject_id);
        case 'artifacts_rejected'
            output_dir = config.dirs.artifacts_rejected;
            dataset_name = sprintf(config.naming.artifacts_rejected, subject_id);
        case 'final'
            output_dir = config.dirs.final;
            dataset_name = sprintf(config.naming.final, subject_id);
        otherwise
            error('Unknown processing stage: %s', stage);
    end
    
    % Add variant to dataset name if specified
    if ~isempty(variant) && ~strcmp(stage, 'preprocessed')
        dataset_name = [dataset_name '-' variant];
    end
    
    % Ensure output directory exists
    if ~exist(output_dir, 'dir')
        mkdir(output_dir);
    end
    
    % Save the dataset
    EEG = pop_editset(EEG, 'setname', dataset_name, 'run', []);
    filename = [dataset_name '.set'];
    EEG = pop_saveset(EEG, 'filename', filename, 'filepath', output_dir);
    
    % Update ALLEEG if it exists
    if evalin('base', 'exist(''ALLEEG'', ''var'')')
        ALLEEG = evalin('base', 'ALLEEG');
        CURRENTSET = evalin('base', 'CURRENTSET');
        
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset(EEG);
        
        assignin('base', 'ALLEEG', ALLEEG);
        assignin('base', 'EEG', EEG);
        assignin('base', 'CURRENTSET', CURRENTSET);
    end
    
    fprintf('    Saved to %s: %s\n', stage, filename);
end