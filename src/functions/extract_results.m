
function [trial_data, events, time_vector, channel_labels] = extract_results(subject_id, config, pipeline_type)
    % extract_results - Extract analysis data from epoched EEG datasets
    %
    % extract_results loads epoched EEG data from the 05_epoched stage and
    % extracts key analysis components for ERP analysis including trial data,
    % rejection markers, event codes, response events, and time vectors.
    % Supports both EEGLAB and ERPLAB processing pipelines.
    %
    % Syntax: 
    %   [trial_data, events, time_vector, channel_labels] = ...
    %       extract_results(subject_id, config)
    %   [trial_data, events, time_vector, channel_labels] = ...
    %       extract_results(subject_id, config, pipeline_type)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'jerry')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.epoched     - Epoched data directory path
    %                .naming           - File naming conventions
    %                .event_codes      - Expected event codes
    %   pipeline_type - Optional string, processing pipeline:
    %                   'eeglab' (default) - Use EEGLAB rejection markers
    %                   'erplab'           - Use ERPLAB rejection markers
    %
    % Outputs:
    %   trial_data      - 3D matrix [channels × time_points × trials] containing EEG data
    %   events          - Vector [1 × trials] of event codes for each epoch
    %   time_vector     - Vector [1 × time_points] of time values in seconds for ERP plotting
    %   channel_labels  - String array [1 × channels] of channel names
    %
    % Processing Steps:
    %   1. Load epoched EEG data from appropriate stage directory
    %   2. Extract 3D trial data matrix (channels × time × trials)
    %   3. Extract rejection flags from EEG.reject structure
    %   4. Parse event structure to identify trial and response markers
    %   5. Generate time vector based on epoch window and sampling rate
    %   6. Validate output dimensions and data integrity
    %
    % Event Processing:
    %   - trial_markers: Event code that triggered each epoch
    %   - response_markers: Next event code following the trial event
    %   - Handles missing or irregular response events gracefully
    %   - Supports both EEGLAB and ERPLAB event structures
    %
    % Pipeline Support:
    %   EEGLAB Pipeline:
    %     - Uses EEG.reject.rejthresh for rejection markers
    %     - Loads from '[subject]-epochs.set' files
    %   
    %   ERPLAB Pipeline:
    %     - Uses EEG.reject.rejmanual for rejection markers
    %     - Loads from '[subject]-epochs-erplab.set' files
    %
    % Examples:
    %   % Extract from EEGLAB epoched data
    %   config = default_config();
    %   [data, events, time, channels] = extract_results('elaine', config);
    %
    %   % Extract from ERPLAB epoched data
    %   [data, events, time, channels] = extract_results('helen', config, 'erplab');
    %
    %   % Use extracted data for ERP analysis
    %   avg_erp = mean(data, 3);
    %   plot(time, avg_erp(electrode_idx, :));
    %
    % Error Handling:
    %   - Comprehensive validation of input parameters
    %   - File existence checking with informative error messages
    %   - Dimension consistency validation across outputs
    %   - Graceful handling of missing event information
    %
    % Notes:
    %   - Loads data from 05_epoched stage (contains rejection markers)
    %   - Time vector uses EEG.times for exact alignment
    %   - Rejection vectors indicate marked trials (not yet removed)
    %   - Compatible with standard ERP analysis workflows
    %   - Response detection assumes sequential event ordering
    %
    % See also: load_eeg_from_stage, eeg_epochs, erplab_art_rej
    %
    % Author: Matt Kmiecik
    
    %% INPUT VALIDATION AND DEFAULTS
    if nargin < 3
        pipeline_type = 'eeglab';
    end
    
    % Validate pipeline_type
    if ~ischar(pipeline_type) && ~isstring(pipeline_type)
        error('pipeline_type must be a string: "eeglab" or "erplab"');
    end
    
    valid_pipelines = {'eeglab', 'erplab'};
    if ~any(strcmpi(pipeline_type, valid_pipelines))
        error('pipeline_type must be "eeglab" or "erplab"');
    end
    
    % Validate inputs
    if ~ischar(subject_id) && ~isstring(subject_id)
        error('subject_id must be a string or character array');
    end
    
    if ~isstruct(config)
        error('config must be a structure from default_config()');
    end
    
    fprintf('=== EXTRACTING RESULTS FOR SUBJECT: %s ===\n', subject_id);
    fprintf('  Pipeline type: %s\n', pipeline_type);
    
    try
        % Setup diary logging with timestamp
        log_dir = fullfile(config.dirs.logs, subject_id);
        if ~exist(log_dir, 'dir'), mkdir(log_dir); end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        diary(fullfile(log_dir, [subject_id '_extract_results_' timestamp '.txt']));

        %% LOAD EPOCHED EEG DATA
        fprintf('  Loading epoched EEG data...\n');
        
        % Set up loading options for the appropriate pipeline
        load_opts = struct();
        if strcmpi(pipeline_type, 'erplab')
            pipeline_type = 'erplab';
        end

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
        
        fprintf('  Data dimensions: %d channels × %d time points × %d trials\n', ...
            EEG.nbchan, EEG.pnts, EEG.trials);
        
        %% EXTRACT TRIAL DATA MATRIX
        fprintf('  Extracting trial data matrix...\n');
        trial_data = EEG.data;  % Already in format [channels × time_points × trials]
        
        %% EXTRACT REJECTION MARKERS
        fprintf('  Extracting rejection markers...\n');
        
        % Initialize rejected_trials as empty logical vector
        rejected_trials = false(1, EEG.trials);
        
        % Extract rejection flags based on pipeline type
        if strcmpi(pipeline_type, 'erplab')
            % ERPLAB uses rejmanual field
            if isfield(EEG.reject, 'rejmanual') && ~isempty(EEG.reject.rejmanual)
                rejected_trials = logical(EEG.reject.rejmanual);
                fprintf('  Found %d trials marked for rejection (ERPLAB)\n', sum(rejected_trials));
            else
                fprintf('  No ERPLAB rejection markers found\n');
            end
        else
            % EEGLAB uses rejthresh field
            if isfield(EEG.reject, 'rejthresh') && ~isempty(EEG.reject.rejthresh)
                rejected_trials = logical(EEG.reject.rejthresh);
                fprintf('  Found %d trials marked for rejection (EEGLAB)\n', sum(rejected_trials));
            else
                fprintf('  No EEGLAB rejection markers found\n');
            end
        end
        
        %% EXTRACT EVENT MARKERS (ROBUSTLY)
        fprintf('  Extracting event markers...\n');

        events = zeros(1, EEG.trials); % preallocate numeric vector
        
        for trial = 1:EEG.trials
            % Get the event types for this epoch
            trial_events = string(EEG.epoch(trial).eventtype);
            
            % Find which trial_events are present in config.event_codes
            matching_indices = ismember(trial_events, config.event_codes);
            
            if any(matching_indices)
                % Take the first matching event as the trial marker
                selected_events = trial_events(matching_indices);
                events(trial) = double(selected_events(1));
            else
                % No matching event found - set to NaN or 0
                events(trial) = 0;
                fprintf('    Warning: No matching event found for trial %d\n', trial);
            end
        end

        %% GENERATE TIME VECTOR
        fprintf('  Generating time vector...\n');
        
        % Create time vector based on epoch timing
        if isfield(EEG, 'times') && ~isempty(EEG.times)
            % Use EEGLAB's time vector if available (most accurate)
            time_vector = EEG.times / 1000;  % Convert from ms to seconds
        else
            % Generate time vector from epoch parameters
            time_vector = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
        end
        
        fprintf('  Time vector: %.3f to %.3f seconds (%d points)\n', ...
            time_vector(1), time_vector(end), length(time_vector));

        %% EXTRACT CHANNEL LABELS
        channel_labels = string({EEG.chanlocs.labels});
        
        %% VALIDATION AND SUMMARY
        fprintf('  Validating extracted data...\n');
        
        % Validate dimensions
        expected_trials = EEG.trials;
        if size(trial_data, 3) ~= expected_trials
            error('Trial data dimension mismatch: expected %d trials, got %d', ...
                expected_trials, size(trial_data, 3));
        end
        
        if length(rejected_trials) ~= expected_trials
            error('Rejection vector dimension mismatch: expected %d trials, got %d', ...
                expected_trials, length(rejected_trials));
        end
        
        if length(events) ~= expected_trials
            error('Trial markers dimension mismatch: expected %d trials, got %d', ...
                expected_trials, length(events));
        end
        
        if length(time_vector) ~= EEG.pnts
            error('Time vector dimension mismatch: expected %d points, got %d', ...
                EEG.pnts, length(time_vector));
        end

        if EEG.nbchan ~= length(channel_labels)
            error('Channel data mismatch: expected %d channels, got %d', ...
                EEG.nbchan, length(channel_labels));
        end

        % Summary
        fprintf('=== EXTRACTION SUMMARY ===\n');
        fprintf('  Subject: %s\n', subject_id);
        fprintf('  Data shape: %d channels × %d time points × %d trials\n', ...
            size(trial_data, 1), size(trial_data, 2), size(trial_data, 3));
        fprintf('  Rejected trials: %d (%.1f%%)\n', ...
            sum(rejected_trials), (sum(rejected_trials)/length(rejected_trials))*100);
        fprintf('  Time range: %.3f to %.3f seconds\n', time_vector(1), time_vector(end));
        fprintf('  Valid events: %d\n', length(events));
        fprintf('  Channels: %d\n', length(channel_labels));
        
        fprintf('  Extraction completed successfully for %s\n', subject_id);
        diary off;

    catch ME
        fprintf('  ERROR in extracting results for %s: %s\n', subject_id, ME.message);
        fprintf('  Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        diary off;
        rethrow(ME);
    end
end