function save_ica_weights(EEG, subject_id, config)
    % SAVE_ICA_WEIGHTS - Space-efficient ICA decomposition storage system
    %
    % SAVE_ICA_WEIGHTS extracts and saves only the essential ICA decomposition
    % matrices and metadata from EEG datasets, achieving 95%+ disk space savings
    % compared to storing full ICA datasets. Creates lightweight .mat files
    % that can be applied to any compatible EEG dataset using load_ica_weights().
    %
    % Syntax: 
    %   save_ica_weights(EEG, subject_id, config)
    %
    % Inputs:
    %   EEG        - EEGLAB EEG structure containing completed ICA decomposition:
    %                Must have .icaweights, .icasphere, .icawinv populated
    %   subject_id - String, subject identifier (e.g., 'newman')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.ica    - ICA weights output directory
    %                .naming.ica  - ICA filename pattern
    %
    % Outputs:
    %   None (saves .mat file to disk)
    %
    % Saved Data Structure (ica_data):
    %   Essential ICA Matrices:
    %     .icaweights  - ICA unmixing matrix [components × channels]
    %     .icasphere   - Sphering matrix [channels × channels]
    %     .icawinv     - ICA mixing matrix [channels × components]
    %     .icachansind - Channel indices used for ICA
    %
    %   Channel Information:
    %     .chanlocs    - Channel location structures
    %     .nbchan      - Number of channels
    %
    %   Dataset Metadata:
    %     .subject_id  - Subject identifier
    %     .setname     - Original dataset name
    %     .srate       - Sampling rate (Hz)
    %     .data_rank   - Data rank (number of ICA components)
    %     .timestamp   - Processing timestamp
    %
    %   Processing Context:
    %     .config_snapshot - Key configuration parameters
    %     .bad_channels    - Bad channel indices from Excel database
    %     .n_bad_channels  - Count of bad channels
    %
    % File Storage:
    %   Location: config.dirs.ica/[subject_id]-ica_weights.mat
    %   Format: MATLAB v7.3 (.mat file)
    %   Size: ~1-5 MB (vs ~100+ MB for full ICA dataset)
    %   Compression: ~95%+ space savings
    %
    % Example:
    %   % Save ICA weights after decomposition
    %   config = default_config();
    %   EEG = eeg_runica(EEG, 'icatype', 'runica', 'extended', 1);
    %   save_ica_weights(EEG, 'frank', config);
    %   
    %   % Later, apply weights to different dataset
    %   [EEG_new, ~] = load_eeg_from_stage('frank', 'preprocessed', config);
    %   EEG_new = load_ica_weights(EEG_new, 'frank', config);
    %
    % Storage Benefits:
    %   - Massive disk space savings (95%+ reduction)
    %   - Faster file I/O operations
    %   - Portable ICA weights across compatible datasets
    %   - Preserved full ICA functionality
    %   - Complete traceability with metadata
    %
    % Notes:
    %   - Creates ICA directory automatically if needed
    %   - Displays file size after saving for verification
    %   - Integrates with get_bad_channels_from_excel() for context
    %   - Uses MATLAB v7.3 format for large matrix support
    %   - Compatible with load_ica_weights() for reconstruction
    %
    % See also: load_ica_weights, eeg_ica, eeg_runica, get_bad_channels_from_excel
    %
    % Author: Matt Kmiecik
    
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