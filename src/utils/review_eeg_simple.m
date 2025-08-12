% FILE: src/utils/review_eeg_simple.m

function EEG = review_eeg_simple(subject_id, stage, config, options)
    % REVIEW_EEG_SIMPLE - Simplified EEG data review function
    %
    % A simpler version of review_eeg_data that avoids EEGLAB workspace issues
    % by directly opening the plotting functions without managing ALLEEG.
    %
    % Syntax: 
    %   EEG = review_eeg_simple(subject_id, stage, config)
    %   EEG = review_eeg_simple(subject_id, stage, config, options)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'CS_05_16_1')
    %   stage      - String, processing stage to load
    %   config     - Configuration structure from default_config()
    %   options    - Optional struct with fields:
    %                .variant - '1Hz' for 1Hz filtered data (default: '')
    %                .pipeline_type - 'eeglab' or 'erplab' for epoched/artifacts_rejected stages (default: 'eeglab')
    %
    % Examples:
    %   EEG = review_eeg_simple('CS_05_16_1', 'preprocessed', config);
    %   opts.variant = '1Hz'; 
    %   EEG = review_eeg_simple('CS_05_16_1', 'preprocessed', config, opts);
    %   opts.pipeline_type = 'erplab';
    %   EEG = review_eeg_simple('CS_05_16_1', 'epoched', config, opts);

    % Handle optional inputs
    if nargin < 4
        options = struct();
    end
    
    if ~isfield(options, 'variant'), options.variant = ''; end
    if ~isfield(options, 'pipeline_type'), options.pipeline_type = 'eeglab'; end
    
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
                if strcmp(stage, 'preprocessed_1hz') || strcmp(options.variant, '1Hz')
                    fprintf('  Loading 1Hz preprocessed data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config, '1Hz');
                else
                    fprintf('  Loading 0.1Hz preprocessed data...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config);
                end
                
            case 'ica'
                % Load preprocessed data and apply ICA weights
                if strcmp(options.variant, '1Hz')
                    fprintf('  Loading 1Hz preprocessed data with ICA weights...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config, '1Hz');
                else
                    fprintf('  Loading 0.1Hz preprocessed data with ICA weights...\n');
                    [EEG, ~] = load_eeg_from_stage(subject_id, 'preprocessed', config);
                end
                EEG = load_ica_weights(EEG, subject_id, config);
                
            case 'components_rejected'
                fprintf('  Loading component-rejected data...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'components_rejected', config);
                
            case 'epoched'
                if strcmp(options.pipeline_type, 'erplab')
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
                if strcmp(options.pipeline_type, 'erplab')
                    fprintf('  Loading ERPLAB artifact-rejected data...\n');
                    % Load ERPLAB artifact-rejected data (final clean data)
                    art_rej_dir = config.dirs.artifacts_rejected;
                    filename = sprintf(config.naming.artifacts_rejected, subject_id);
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
                error('Unknown stage: %s. Valid stages: raw, preprocessed, ica, components_rejected, epoched, artifacts_rejected, final', stage);
        end
        
        %% DISPLAY DATA INFORMATION
        display_data_info_simple(EEG, stage);
        
        %% OPEN SCROLLING DATA VIEW
        fprintf('  Opening data scrolling view...\n');
        light_green = [204, 255, 106] / 255; %  color for rej
        
        if strcmp(stage, 'epoched') || strcmp(stage, 'artifacts_rejected')
            if strcmp(options.pipeline_type, 'erplab')
                % Check if there are any rejections marked for ERPLAB-based
                if isfield(EEG.reject, 'rejmanual') && any(EEG.reject.rejmanual)
                    fprintf('  Found %d trials marked for rejection\n', sum(EEG.reject.rejmanual));
                    winrej = trial2eegplot(EEG.reject.rejmanual, EEG.reject.rejmanualE, EEG.pnts, light_green);
                    eegplot(EEG.data, 'srate', EEG.srate, 'winrej', winrej, 'events', EEG.event);
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
