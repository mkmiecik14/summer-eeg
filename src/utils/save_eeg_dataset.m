% FILE: src/utils/save_eeg_dataset.m

function EEG = save_eeg_dataset(EEG, dataset_name, output_dir)
    % SAVE_EEG_DATASET - Standardized EEG dataset saving
    %
    % Handles all the standard steps for saving an EEG dataset including
    % setting the dataset name, saving the file, and updating ALLEEG.
    %
    % Syntax: EEG = save_eeg_dataset(EEG, dataset_name, output_dir)
    %
    % Inputs:
    %   EEG          - EEG structure to save
    %   dataset_name - String, name for the dataset (without .set extension)
    %   output_dir   - String, directory to save the file
    %
    % Outputs:
    %   EEG - Updated EEG structure
    %
    % Example:
    %   EEG = save_eeg_dataset(EEG, 'sub001-prepro', '/path/to/output');

    % Set dataset name
    EEG = pop_editset(EEG, 'setname', dataset_name, 'run', []);
    
    % Save the dataset
    filename = [dataset_name '.set'];
    EEG = pop_saveset(EEG, 'filename', filename, 'filepath', output_dir);
    
    % Update ALLEEG if it exists in workspace (for EEGLAB compatibility)
    if evalin('base', 'exist(''ALLEEG'', ''var'')')
        ALLEEG = evalin('base', 'ALLEEG');
        CURRENTSET = evalin('base', 'CURRENTSET');
        
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
        EEG = eeg_checkset(EEG);
        
        % Update base workspace
        assignin('base', 'ALLEEG', ALLEEG);
        assignin('base', 'EEG', EEG);
        assignin('base', 'CURRENTSET', CURRENTSET);
    end
    
    fprintf('    Saved: %s\n', fullfile(output_dir, filename));
end