% FILE: src/utils/save_eeg_to_stage.m

function EEG = save_eeg_to_stage(EEG, subject_id, stage, config, variant)
    % SAVE_EEG_TO_STAGE - Save EEG data to appropriate stage directory
    %
    % Saves EEG data to the correct stage directory with proper naming
    % conventions. Handles both standard stages and variants.
    %
    % Syntax: EEG = save_eeg_to_stage(EEG, subject_id, stage, config, variant)
    %
    % Inputs:
    %   EEG        - EEG structure to save
    %   subject_id - String, subject identifier
    %   stage      - String, processing stage ('preprocessed', 'ica', etc.)
    %   config     - Configuration structure
    %   variant    - String, optional variant suffix (e.g., '1Hz')
    %
    % Outputs:
    %   EEG - Updated EEG structure
    %
    % Examples:
    %   EEG = save_eeg_to_stage(EEG, 'sub001', 'preprocessed', config);
    %   EEG = save_eeg_to_stage(EEG, 'sub001', 'preprocessed', config, '1Hz');

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