% FILE: src/utils/save_ica_weights.m

function save_ica_weights(EEG, subject_id, config)
    % SAVE_ICA_WEIGHTS - Save only ICA weights and essential info to save disk space
    %
    % This function saves only the ICA decomposition results and essential
    % metadata instead of the full EEG dataset, significantly reducing disk usage.
    %
    % Syntax: save_ica_weights(EEG, subject_id, config)
    %
    % Inputs:
    %   EEG        - EEG structure with ICA results
    %   subject_id - String, subject identifier
    %   config     - Configuration structure
    %
    % Saves:
    %   - ICA weights matrix (icaweights)
    %   - ICA sphere matrix (icasphere) 
    %   - ICA inverse weights (icawinv)
    %   - Channel locations (chanlocs)
    %   - Channel indices used for ICA (icachansind)
    %   - Data rank information
    %   - Bad channels information
    %   - Processing timestamp and parameters
    
    % Create ICA weights structure
    ica_data = struct();
    
    % Essential ICA matrices
    ica_data.icaweights = EEG.icaweights;
    ica_data.icasphere = EEG.icasphere;
    ica_data.icawinv = EEG.icawinv;
    
    % Channel information
    ica_data.chanlocs = EEG.chanlocs;
    ica_data.icachansind = EEG.icachansind;
    ica_data.nbchan = EEG.nbchan;
    
    % Dataset metadata
    ica_data.subject_id = subject_id;
    ica_data.setname = EEG.setname;
    ica_data.srate = EEG.srate;
    ica_data.data_rank = size(EEG.icaweights, 1);
    
    % Processing information
    ica_data.timestamp = datetime('now');
    ica_data.config_snapshot = struct();
    ica_data.config_snapshot.reference_channels = config.reference_channels;
    ica_data.config_snapshot.highpass_1hz = config.highpass_1hz;
    
    % Bad channels info (if available in workspace)
    try
        bad_channels = get_bad_channels_from_excel(subject_id, config);
        ica_data.bad_channels = bad_channels;
        ica_data.n_bad_channels = length(bad_channels);
    catch
        ica_data.bad_channels = [];
        ica_data.n_bad_channels = 0;
    end
    
    % File naming and saving
    dataset_name = sprintf(config.naming.ica, subject_id);
    filename = [dataset_name '_weights.mat'];
    output_path = fullfile(config.dirs.ica, filename);
    
    % Ensure directory exists
    if ~exist(config.dirs.ica, 'dir')
        mkdir(config.dirs.ica);
    end
    
    % Save the lightweight ICA data
    save(output_path, 'ica_data', '-v7.3');
    
    fprintf('    Saved ICA weights to: %s (%.2f MB)\n', filename, ...
        get_file_size_mb(output_path));
end

function size_mb = get_file_size_mb(filepath)
    % Helper function to get file size in MB
    file_info = dir(filepath);
    size_mb = file_info.bytes / (1024 * 1024);
end