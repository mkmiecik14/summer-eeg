function EEG = load_ica_weights(EEG, subject_id, config)
    % LOAD_ICA_WEIGHTS - Apply space-efficient ICA decomposition to EEG data
    %
    % LOAD_ICA_WEIGHTS loads pre-computed ICA weights from lightweight .mat files
    % and applies the complete ICA decomposition to the target EEG structure.
    % This space-efficient approach saves 95%+ disk space compared to storing
    % full ICA datasets while maintaining complete functionality.
    %
    % Syntax: 
    %   EEG = load_ica_weights(EEG, subject_id, config)
    %
    % Inputs:
    %   EEG        - Target EEGLAB EEG structure to receive ICA decomposition
    %   subject_id - String, subject identifier (e.g., 'kramer')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.ica    - ICA weights directory path
    %                .naming.ica  - ICA filename pattern
    %
    % Outputs:
    %   EEG - EEGLAB EEG structure with complete ICA decomposition applied:
    %         .icaweights  - ICA unmixing matrix
    %         .icasphere   - Sphering matrix
    %         .icawinv     - ICA mixing matrix (inverse weights)
    %         .icachansind - Channel indices used for ICA
    %         .chanlocs    - Matching channel locations (if compatible)
    %         .etc.ica_weights_source - Metadata about ICA source
    %
    % ICA Weights File Contains:
    %   - icaweights, icasphere, icawinv matrices
    %   - Channel information and compatibility data
    %   - Processing metadata (timestamp, data rank, bad channels)
    %   - Quality control information
    %
    % Validation:
    %   - Channel count compatibility between target EEG and ICA data
    %   - Sampling rate compatibility (warns if different)
    %   - ICA matrix dimension consistency
    %   - Channel index bounds checking
    %
    % Example:
    %   % Apply ICA weights to preprocessed data for component analysis
    %   config = default_config();
    %   [EEG, ~] = load_eeg_from_stage('morty', 'preprocessed', config);
    %   EEG = load_ica_weights(EEG, 'morty', config);
    %   pop_selectcomps(EEG, [1:35]); % Review first 35 components
    %
    % Notes:
    %   - ICA weights files are ~1-5MB vs ~100+MB for full ICA datasets
    %   - Clears existing icaact (activations recomputed when needed)
    %   - Preserves target EEG channel locations if incompatible
    %   - Stores source metadata for traceability
    %   - Works with any compatible EEG dataset (same channel count/type)
    %
    % See also: save_ica_weights, eeg_ica, pop_selectcomps, load_eeg_from_stage
    %
    % Author: Matt Kmiecik
    
    % Construct filename for ICA weights
    dataset_name = sprintf(config.naming.ica, subject_id);
    filename = [dataset_name '_weights.mat'];
    weights_path = fullfile(config.dirs.ica, filename);
    
    % Check if weights file exists
    if ~exist(weights_path, 'file')
        error('ICA weights file not found: %s', weights_path);
    end
    
    % Load ICA weights data
    fprintf('  Loading ICA weights from: %s\n', filename);
    loaded_data = load(weights_path);
    ica_data = loaded_data.ica_data;
    
    % Validate compatibility
    validate_ica_compatibility(EEG, ica_data);
    
    % Apply ICA weights to target EEG structure
    EEG.icaweights = ica_data.icaweights;
    EEG.icasphere = ica_data.icasphere;
    EEG.icawinv = ica_data.icawinv;
    EEG.icachansind = ica_data.icachansind;
    
    % Ensure channel locations match
    if length(EEG.chanlocs) == length(ica_data.chanlocs)
        EEG.chanlocs = ica_data.chanlocs;
    else
        warning('Channel location mismatch - keeping target EEG chanlocs');
    end
    
    % Clear any existing ICA activations (will be recomputed if needed)
    EEG.icaact = [];
    
    % Add metadata about ICA source
    EEG.etc.ica_weights_source = struct();
    EEG.etc.ica_weights_source.subject_id = ica_data.subject_id;
    EEG.etc.ica_weights_source.timestamp = ica_data.timestamp;
    EEG.etc.ica_weights_source.data_rank = ica_data.data_rank;
    EEG.etc.ica_weights_source.bad_channels = ica_data.bad_channels;
    
    fprintf('  Applied ICA weights (%d components) to %s\n', ...
        size(ica_data.icaweights, 1), EEG.setname);
end

function validate_ica_compatibility(EEG, ica_data)
    % Validate that ICA weights can be applied to target EEG
    
    % Check number of channels
    if EEG.nbchan ~= ica_data.nbchan
        error('Channel count mismatch: Target EEG has %d channels, ICA data has %d channels', ...
            EEG.nbchan, ica_data.nbchan);
    end
    
    % Check sampling rate compatibility (warn if different)
    if abs(EEG.srate - ica_data.srate) > 1
        warning('Sampling rate mismatch: Target EEG = %.1f Hz, ICA data = %.1f Hz', ...
            EEG.srate, ica_data.srate);
    end
    
    % Check ICA matrix dimensions
    expected_components = size(ica_data.icaweights, 1);
    expected_channels = size(ica_data.icaweights, 2);
    
    if expected_channels ~= EEG.nbchan
        error('ICA weights matrix dimension mismatch: Expected %d channels, got %d', ...
            expected_channels, EEG.nbchan);
    end
    
    % Validate channel indices
    if ~isempty(ica_data.icachansind)
        if max(ica_data.icachansind) > EEG.nbchan
            error('ICA channel indices exceed target EEG channel count');
        end
    end
    
    fprintf('  ICA compatibility validated (%d components, %d channels)\n', ...
        expected_components, expected_channels);
end