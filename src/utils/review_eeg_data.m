% FILE: src/utils/review_eeg_data.m

function EEG = review_eeg_data(subject_id, stage, config, options)
    % REVIEW_EEG_DATA - Load EEG data from any stage and open GUI for inspection
    %
    % This function provides a flexible way to load and visually inspect EEG data
    % from any processing stage. It handles different data types including ICA
    % weights and opens the EEGLAB GUI for scrolling through channel data.
    %
    % Syntax: 
    %   EEG = review_eeg_data(subject_id, stage, config)
    %   EEG = review_eeg_data(subject_id, stage, config, options)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'CS_05_16_1')
    %   stage      - String, processing stage to load:
    %                'raw' - Raw data from data directory
    %                'preprocessed' - Preprocessed data (default: 0.1Hz)
    %                'preprocessed_1hz' - 1Hz preprocessed data
    %                'ica' - Load preprocessed data with ICA weights applied
    %                'components_rejected' - After ICA component rejection
    %                'epoched' - Epoched data
    %                'artifacts_rejected' - After artifact rejection
    %                'final' - Final analysis-ready data
    %   config     - Configuration structure from default_config()
    %   options    - Optional struct with fields:
    %                .apply_ica - true/false, apply ICA weights if available
    %                .variant - '1Hz' for 1Hz data variants
    %                .gui_type - 'scroll', 'plot', 'both' (default: 'scroll')
    %                .load_events - true/false, load event information
    %
    % Outputs:
    %   EEG - Loaded EEG structure
    %
    % Examples:
    %   % Review raw data
    %   EEG = review_eeg_data('CS_05_16_1', 'raw', config);
    %
    %   % Review preprocessed data with ICA applied
    %   EEG = review_eeg_data('CS_05_16_1', 'ica', config);
    %
    %   % Review 1Hz preprocessed data
    %   opts.variant = '1Hz';
    %   EEG = review_eeg_data('CS_05_16_1', 'preprocessed', config, opts);
    %
    %   % Review epoched data with plot instead of scroll
    %   opts.gui_type = 'plot';
    %   EEG = review_eeg_data('CS_05_16_1', 'epoched', config, opts);

    % Handle optional inputs
    if nargin < 4
        options = struct();
    end
    
    % Set default options
    if ~isfield(options, 'apply_ica'), options.apply_ica = false; end
    if ~isfield(options, 'variant'), options.variant = ''; end
    if ~isfield(options, 'gui_type'), options.gui_type = 'scroll'; end
    if ~isfield(options, 'load_events'), options.load_events = true; end
    
    fprintf('=== REVIEWING EEG DATA: %s (%s stage) ===\n', subject_id, stage);
    
    try
        %% LOAD DATA BASED ON STAGE
        switch lower(stage)
            case 'raw'
                EEG = load_raw_data(subject_id, config);
                
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
                options.apply_ica = true; % Force ICA display
                
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
        
        %% APPLY ICA WEIGHTS IF REQUESTED AND AVAILABLE
        if options.apply_ica && ~strcmp(stage, 'ica') && isempty(EEG.icaweights)
            try
                fprintf('  Applying ICA weights...\n');
                EEG = load_ica_weights(EEG, subject_id, config);
            catch ME
                warning('Could not load ICA weights: %s', ME.message);
            end
        end
        
        %% LOAD INTO EEGLAB WORKSPACE
        fprintf('  Loading into EEGLAB workspace...\n');
        
        % Get or initialize ALLEEG from base workspace
        if evalin('base', 'exist(''ALLEEG'', ''var'')')
            ALLEEG = evalin('base', 'ALLEEG');
        else
            ALLEEG = [];
        end
        
        [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, 0);
        
        % Update workspace variables
        assignin('base', 'ALLEEG', ALLEEG);
        assignin('base', 'EEG', EEG);
        assignin('base', 'CURRENTSET', CURRENTSET);
        
        %% DISPLAY DATA INFORMATION
        display_data_info(EEG, stage, options);
        
        %% OPEN GUI FOR REVIEW
        fprintf('  Opening GUI for data review...\n');
        switch lower(options.gui_type)
            case 'scroll'
                % Continuous data scrolling view
                try
                    eeglab redraw;
                catch
                    % If redraw fails, just continue without it
                    fprintf('  Warning: Could not redraw EEGLAB GUI\n');
                end
                pop_eegplot(EEG, 1, 1, 1);
                
            case 'plot'
                % Channel data plot
                if EEG.trials > 1
                    % Epoched data - plot average
                    try
                        pop_timtopo(EEG, [-200 3000], [NaN], 'ERP data and scalp maps');
                    catch
                        % Fallback to simple plot if timtopo fails
                        fprintf('  Warning: Could not create timtopo plot, using simple ERP plot\n');
                        figure; plot(EEG.times, mean(EEG.data, 3)', 'LineWidth', 1);
                        title('Average ERP across channels');
                        xlabel('Time (ms)'); ylabel('Amplitude (uV)');
                    end
                else
                    % Continuous data - plot channels
                    pop_eegplot(EEG, 1, 1, 1);
                end
                
            case 'both'
                % Open both scroll and plot
                try
                    eeglab redraw;
                catch
                    % If redraw fails, just continue without it
                    fprintf('  Warning: Could not redraw EEGLAB GUI\n');
                end
                pop_eegplot(EEG, 1, 1, 1);
                if EEG.trials > 1
                    try
                        pop_timtopo(EEG, [-200 3000], [NaN], 'ERP data and scalp maps');
                    catch
                        % Fallback to simple plot if timtopo fails
                        fprintf('  Warning: Could not create timtopo plot\n');
                        figure; plot(EEG.times, mean(EEG.data, 3)', 'LineWidth', 1);
                        title('Average ERP across channels');
                        xlabel('Time (ms)'); ylabel('Amplitude (uV)');
                    end
                end
                
            otherwise
                warning('Unknown gui_type: %s. Using scroll view.', options.gui_type);
                pop_eegplot(EEG, 1, 1, 1);
        end
        
        %% OPTIONAL: DISPLAY ICA COMPONENTS IF AVAILABLE
        if options.apply_ica && ~isempty(EEG.icaweights)
            answer = questdlg('Would you like to review ICA components?', ...
                'ICA Review', 'Yes', 'No', 'No');
            if strcmp(answer, 'Yes')
                pop_selectcomps(EEG, [1:min(35, size(EEG.icaweights,1))]);
            end
        end
        
        fprintf('✓ Data review setup complete for %s (%s stage)\n', subject_id, stage);
        fprintf('  Use EEGLAB GUI to scroll through data\n');
        fprintf('  Close plot windows when finished reviewing\n');
        
    catch ME
        fprintf('✗ Error loading data for review: %s\n', ME.message);
        rethrow(ME);
    end
end

%% HELPER FUNCTIONS

function EEG = load_raw_data(subject_id, config)
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

function display_data_info(EEG, stage, options)
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
        %unique_events = unique({EEG.event.type});

        % Convert all event types to strings, then get unique values
        event_types_str = cellfun(@string, {EEG.event.type}, 'UniformOutput', false);
        unique_events = unique([event_types_str{:}]);

        fprintf('Event Types: %s\n', strjoin(unique_events, ', '));
        fprintf('Total Events: %d\n', length(EEG.event));
    end
    
    fprintf('------------------------\n\n');
end