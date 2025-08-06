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
    %   options    - Optional struct with variant field
    %
    % Examples:
    %   EEG = review_eeg_simple('CS_05_16_1', 'preprocessed', config);
    %   opts.variant = '1Hz'; 
    %   EEG = review_eeg_simple('CS_05_16_1', 'preprocessed', config, opts);

    % Handle optional inputs
    if nargin < 4
        options = struct();
    end
    
    if ~isfield(options, 'variant'), options.variant = ''; end
    
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
                fprintf('  Loading epoched data...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'epoched', config);
                
            case 'artifacts_rejected'
                fprintf('  Loading artifact-rejected data...\n');
                [EEG, ~] = load_eeg_from_stage(subject_id, 'artifacts_rejected', config);
                
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
        pop_eegplot(EEG, 1, 1, 1);
        
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