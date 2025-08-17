function EEG = save_eeg_dataset(EEG, dataset_name, output_dir)
    % SAVE_EEG_DATASET - Standardized EEG dataset saving with workspace management
    %
    % SAVE_EEG_DATASET provides a unified interface for saving EEGLAB datasets
    % with proper naming, workspace integration, and directory management.
    % Handles all standard EEGLAB saving procedures including dataset naming,
    % file saving, and ALLEEG workspace synchronization.
    %
    % Syntax: 
    %   EEG = save_eeg_dataset(EEG, dataset_name, output_dir)
    %
    % Inputs:
    %   EEG          - EEGLAB EEG structure to save
    %   dataset_name - String, dataset name identifier (without .set extension)
    %                  Will be used for both .setname and filename
    %   output_dir   - String, absolute path to target directory
    %                  Directory will be created if it doesn't exist
    %
    % Outputs:
    %   EEG - Updated EEGLAB EEG structure with:
    %         .setname updated to match dataset_name
    %         .filename and .filepath set to save location
    %         Validated by eeg_checkset()
    %
    % Processing Steps:
    %   1. Updates EEG.setname using pop_editset()
    %   2. Saves dataset as .set/.fdt files using pop_saveset()
    %   3. Updates ALLEEG workspace if available
    %   4. Validates dataset integrity with eeg_checkset()
    %   5. Synchronizes workspace variables (ALLEEG, EEG, CURRENTSET)
    %
    % Workspace Management:
    %   - Automatically detects and updates ALLEEG workspace
    %   - Uses eeg_store() for proper EEGLAB integration
    %   - Maintains workspace synchronization for GUI compatibility
    %   - Safe for both scripted and interactive use
    %
    % Example:
    %   % Save preprocessed data with proper naming
    %   output_dir = '/path/to/output/02_preprocessed';
    %   EEG = save_eeg_dataset(EEG, 'george-prepro-01hz', output_dir);
    %
    %   % Save within pipeline workflow
    %   config = default_config();
    %   dataset_name = sprintf(config.naming.preprocessed_01hz, subject_id);
    %   EEG = save_eeg_dataset(EEG, dataset_name, config.dirs.preprocessed);
    %
    % Notes:
    %   - Creates output directory automatically if needed
    %   - Prints confirmation message with full file path
    %   - Maintains EEGLAB workspace compatibility
    %   - Uses standard .set/.fdt format for EEGLAB datasets
    %   - For stage-based saving, prefer save_eeg_to_stage()
    %
    % See also: pop_saveset, pop_editset, eeg_store, save_eeg_to_stage, eeg_checkset
    %
    % Author: Matt Kmiecik

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