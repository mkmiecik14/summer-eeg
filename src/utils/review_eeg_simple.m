
function EEG = review_eeg_simple(subject_id, stage, config, pipeline_type)
    % REVIEW_EEG_SIMPLE - Interactive EEG data review and visualization tool
    %
    % REVIEW_EEG_SIMPLE loads and displays EEG data from any processing stage
    % with interactive plotting capabilities. This simplified version avoids 
    % EEGLAB workspace conflicts while providing comprehensive data inspection.
    %
    % Syntax: 
    %   EEG = review_eeg_simple(subject_id, stage, config)
    %   EEG = review_eeg_simple(subject_id, stage, config, pipeline_type)
    %
    % Inputs:
    %   subject_id    - String, subject identifier (e.g., 'CS_05_16_1')
    %   stage         - String, processing stage to review:
    %                   'raw'                - Raw .bdf data
    %                   'preprocessed'       - Filtered, re-referenced data (0.1Hz)
    %                   'preprocessed_1hz'   - Filtered, re-referenced data (1Hz) [EEGLAB only]
    %                   'ica'                - Preprocessed data with ICA weights applied [EEGLAB only]
    %                   'components_rejected'- Data after ICA component removal [EEGLAB only]
    %                   'epoched'            - Segmented data around events
    %                   'artifacts_rejected' - Final clean data (epochs removed)
    %                   'final'              - Analysis-ready datasets
    %   config        - Configuration structure from default_config()
    %   pipeline_type - Optional string, processing pipeline:
    %                   'eeglab' (default) - Uses EEGLAB-based processing files
    %                   'erplab'          - Uses ERPLAB-based processing files
    %
    % Outputs:
    %   EEG           - EEGLAB structure containing the loaded dataset
    %
    % Pipeline Compatibility:
    %   EEGLAB Pipeline: All stages supported
    %   ERPLAB Pipeline: 'raw', 'preprocessed', 'epoched', 'artifacts_rejected', 'final'
    %
    % Interactive Features:
    %   - Automatic data information display (channels, sampling rate, events)
    %   - Opens eegplot() for continuous data scrolling and inspection
    %   - For epoched data: Shows rejected trials highlighted in light green
    %   - For artifact-rejected data: Shows clean epochs only
    %   - Optional ICA component review interface
    %   - Works with both EEGLAB and ERPLAB artifact rejection markers
    %
    % Examples:
    %   % Review preprocessed data (default EEGLAB pipeline)
    %   config = default_config();
    %   EEG = review_eeg_simple('elaine', 'preprocessed', config);
    %
    %   % Review 1Hz variant (EEGLAB only)
    %   EEG = review_eeg_simple('jerry', 'preprocessed_1hz', config);
    %
    %   % Review ERPLAB epoched data with rejection markers
    %   EEG = review_eeg_simple('george', 'epoched', config, 'erplab');
    %
    %   % Review final clean data
    %   EEG = review_eeg_simple('kramer', 'artifacts_rejected', config, 'erplab');
    %
    % Notes:
    %   - Initializes EEGLAB automatically if not already running
    %   - Uses space-efficient ICA weight loading for 'ica' stage
    %   - Supports both manual rejection markers (EEGLAB) and ERPLAB rejection flags
    %   - Close plot windows when finished to free memory
    %
    % See also: review_eeg_data, load_eeg_from_stage, load_ica_weights, default_config
    % 
    % Author: Matt Kmiecik

    % Handle optional inputs
    if nargin < 4 || isempty(pipeline_type)
        pipeline_type = 'eeglab';
    end
    
    % Validate input combinations
    validate_stage_pipeline_combination(stage, pipeline_type);
    
    fprintf('=== REVIEWING EEG DATA: %s (%s stage) ===\n', subject_id, stage);
    
    % Initialize EEGLAB if not already done
    if ~exist('ALLEEG', 'var') || isempty(ALLEEG)
        fprintf('  Initializing EEGLAB...\n');
        [ALLEEG, EEG_temp, CURRENTSET, ALLCOM] = eeglab('nogui');
        clear EEG_temp;
    end
    
    try
        %% LOAD DATA BASED ON STAGE
        switch lower(stage)
            case 'raw'
                EEG = load_raw_data_simple(subject_id, config);
                
            case {'preprocessed', 'preprocessed_1hz'}
                if strcmp(stage, 'preprocessed_1hz')
                    fprintf('  Loading 1Hz preprocessed data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config, '1Hz');
                else
                    fprintf('  Loading 0.1Hz preprocessed data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config);
                end
                
            case 'ica'
                % Load preprocessed data and apply ICA weights
                % Default to 0.1Hz for ICA stage
                fprintf('  Loading 0.1Hz preprocessed data with ICA weights...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config);
                EEG = load_ica_weights(EEG, subject_id, config);
                
            case 'components_rejected'
                fprintf('  Loading component-rejected data...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'components_rejected', config);
                
            case 'epoched'
                if strcmp(pipeline_type, 'erplab')
                    fprintf('  Loading ERPLAB epoched data...\n');
                    % Load ERPLAB epoched data (with rejection markers)
                    epoched_dir = config.dirs.epoched;
                    filename = sprintf(config.naming.epoched_erplab, subject_id);
                    epoched_file = fullfile(epoched_dir, [filename '.set']);
                    if exist(epoched_file, 'file')
                        EEG = pop_loadset(epoched_file);
                    else
                        error('ERPLAB epoched file not found: %s', epoched_file);
                    end
                else
                    fprintf('  Loading EEGLAB epoched data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'epoched', config);
                end
                
            case 'artifacts_rejected'
                if strcmp(pipeline_type, 'erplab')
                    fprintf('  Loading ERPLAB artifact-rejected data...\n');
                    % Load ERPLAB artifact-rejected data (final clean data)
                    art_rej_dir = config.dirs.artifacts_rejected;
                    filename = sprintf(config.naming.artifacts_rejected_erplab, subject_id);
                    art_rej_file = fullfile(art_rej_dir, [filename '.set']);
                    if exist(art_rej_file, 'file')
                        EEG = pop_loadset(art_rej_file);
                    else
                        error('ERPLAB artifact-rejected file not found: %s', art_rej_file);
                    end
                else
                    fprintf('  Loading EEGLAB artifact-rejected data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'artifacts_rejected', config);
                end
                
            case 'final'
                fprintf('  Loading final analysis-ready data...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'final', config);
                
            otherwise
                error('Unknown stage: %s. Valid stages: raw, preprocessed, preprocessed_1hz, ica, components_rejected, epoched, artifacts_rejected, final', stage);
        end
        
        %% DISPLAY DATA INFORMATION
        display_data_info_simple(EEG, stage);
        
        %% OPEN SCROLLING DATA VIEW
        fprintf('  Opening data scrolling view...\n');
        light_green = [204, 255, 106] / 255; %  color for rej
        
        if strcmp(stage, 'epoched')
            if strcmp(pipeline_type, 'erplab')
                % Check if there are any rejections marked for ERPLAB-based
                if isfield(EEG.reject, 'rejmanual') && any(EEG.reject.rejmanual)
                    fprintf('  Found %d trials marked for rejection\n', sum(EEG.reject.rejmanual));
                    winrej = trial2eegplot(EEG.reject.rejmanual, EEG.reject.rejmanualE, EEG.pnts, light_green);
                    eegplot(EEG.data, 'srate', EEG.srate, 'winrej', winrej, 'events', EEG.event);
                else
                    fprintf('  No trials marked for rejection\n');
                    eegplot(EEG.data, 'srate', EEG.srate, 'events', EEG.event);
                end
            else 
                % Check if there are any rejections marked for EEGLAB-based
                if isfield(EEG.reject, 'rejthresh') && any(EEG.reject.rejthresh)
                    fprintf('  Found %d trials marked for rejection\n', sum(EEG.reject.rejthresh));
                    winrej = trial2eegplot(EEG.reject.rejthresh, EEG.reject.rejthreshE, EEG.pnts, light_green);
                    eegplot(EEG.data, 'srate', EEG.srate, 'winrej', winrej, 'events', EEG.event);
                else
                    fprintf('  No trials marked for rejection\n');
                    eegplot(EEG.data, 'srate', EEG.srate, 'events', EEG.event);
                end
            end
        elseif strcmp(stage, 'artifacts_rejected')
            % For artifact-rejected data, plot clean epochs without highlighting rejections
            fprintf('  Displaying clean epochs (artifacts already removed)\n');
            eegplot(EEG.data, 'srate', EEG.srate, 'events', EEG.event);
        else
            pop_eegplot(EEG, 1, 1, 1);
        end
        
        %% OPTIONAL: ICA COMPONENTS
        if ~isempty(EEG.icaweights)
            answer = questdlg('Would you like to review ICA components?', ...
                'ICA Review', 'Yes', 'No', 'No');
            if strcmp(answer, 'Yes')
                pop_selectcomps(EEG, [1:min(35, size(EEG.icaweights,1))]);
            end
        end
        
        fprintf('✓ Data review setup complete for %s (%s stage)\n', subject_id, stage);
        fprintf('  Close plot windows when finished reviewing\n');
        
    catch ME
        fprintf('✗ Error loading data for review: %s\n', ME.message);
        rethrow(ME);
    end
end

%% HELPER FUNCTIONS

function EEG = load_raw_data_simple(subject_id, config)
    % Load raw data from data directory
    fprintf('  Loading raw data...\n');
    data_file = dir(fullfile(config.data_dir, [subject_id '.bdf']));
    
    if isempty(data_file)
        error('Raw data file not found: %s.bdf', subject_id);
    end
    
    EEG = pop_biosig(...
        fullfile(data_file.folder, data_file.name), ...
        'ref', [1], ...
        'refoptions', {'keepref', 'on'}, ...
        'importannot', 'off', ...
        'bdfeventmode', 6);
    
    EEG.setname = [subject_id '_raw_review'];
end

function display_data_info_simple(EEG, stage)
    % Display information about loaded data
    fprintf('\n--- DATA INFORMATION ---\n');
    fprintf('Subject: %s\n', EEG.setname);
    fprintf('Stage: %s\n', stage);
    fprintf('Channels: %d\n', EEG.nbchan);
    fprintf('Sampling Rate: %.1f Hz\n', EEG.srate);
    fprintf('Data Length: %.1f seconds\n', EEG.pnts / EEG.srate);
    
    if EEG.trials > 1
        fprintf('Epochs: %d\n', EEG.trials);
        fprintf('Epoch Length: %.1f seconds\n', (EEG.pnts / EEG.srate));
        fprintf('Time Range: %.1f to %.1f seconds\n', EEG.xmin, EEG.xmax);
    end
    
    if ~isempty(EEG.icaweights)
        fprintf('ICA Components: %d\n', size(EEG.icaweights, 1));
    end
    
    if ~isempty(EEG.event)
        % Convert all event types to strings, then get unique values
        event_types_str = cellfun(@string, {EEG.event.type}, 'UniformOutput', false);
        unique_events = unique([event_types_str{:}]);
        
        fprintf('Event Types: %s\n', strjoin(unique_events, ', '));
        fprintf('Total Events: %d\n', length(EEG.event));
    end
    
    fprintf('------------------------\n\n');
end

function validate_stage_pipeline_combination(stage, pipeline_type)
    % VALIDATE_STAGE_PIPELINE_COMBINATION - Check for invalid stage/pipeline combinations
    %
    % This function prevents common user errors by validating that the requested
    % stage and pipeline type combination is valid.
    
    % Validate pipeline_type
    if ~ismember(pipeline_type, {'eeglab', 'erplab'})
        error('Invalid pipeline_type: %s. Must be ''eeglab'' or ''erplab''.', pipeline_type);
    end
    
    % Define which stages are incompatible with which pipelines
    switch lower(stage)
        case 'preprocessed_1hz'
            if strcmp(pipeline_type, 'erplab')
                error(['Invalid combination: preprocessed_1hz stage is not available for erplab pipeline.' newline ...
                       'ERPLAB preprocessing does not create 1Hz variants.' newline ...
                       'Use ''preprocessed'' stage instead, or switch to ''eeglab'' pipeline.']);
            end
            
        case 'ica'
            if strcmp(pipeline_type, 'erplab')
                error(['Invalid combination: ica stage is not available for erplab pipeline.' newline ...
                       'ERPLAB pipeline does not use ICA decomposition.' newline ...
                       'Use ''eeglab'' pipeline for ICA-based processing.']);
            end
            
        case 'components_rejected'
            if strcmp(pipeline_type, 'erplab')
                error(['Invalid combination: components_rejected stage is not available for erplab pipeline.' newline ...
                       'ERPLAB pipeline does not use ICA component rejection.' newline ...
                       'Use ''eeglab'' pipeline for ICA-based processing.']);
            end
            
        case {'raw', 'preprocessed', 'final'}
            % These stages are valid for both pipelines (though may not always exist)
            
        case {'epoched', 'artifacts_rejected'}
            % These stages are valid for both pipelines but load different files
            % No validation error needed here
            
        otherwise
            % Error will be caught later in the main switch statement
    end
end
