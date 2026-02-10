function [success, results] = extract_results(subject_id, config)
    % EXTRACT_RESULTS - Extract analysis data from final clean EEG datasets
    %
    % EXTRACT_RESULTS loads the final clean EEG dataset from 06_final (after
    % combined artifact rejection) and extracts key analysis components into a
    % structured .mat file for downstream ERP analysis. Recovers original trial
    % numbers using EEGLAB's urevent mapping so that rejected trials can be
    % identified by their original position in the experiment.
    %
    % Syntax:
    %   [success, results] = extract_results(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'MC_05_08_1')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.final       - Final clean data directory (06_final/)
    %                .dirs.logs        - Log file directory
    %                .naming.final     - Final output filename pattern
    %                .event_codes      - Expected stimulus event codes
    %
    % Outputs:
    %   success - Logical, true if extraction completed successfully
    %   results - Structure containing extracted data:
    %             .data     - 3D matrix [channels x time_points x trials]
    %             .time     - Time vector in seconds [1 x time_points]
    %             .channels - Cell array of channel labels {1 x channels}
    %             .trials   - Original trial numbers [1 x trials]
    %             .triggers - Stimulus event codes [1 x trials]
    %
    % Output Files:
    %   - Results .mat: output/06_final/[subject]-final.mat
    %   - Log file:     output/logs/[subject]/[subject]_extract_results_[timestamp].txt
    %
    % Processing Steps:
    %   1. Load final clean EEG dataset from 06_final/
    %   2. Extract 3D data matrix (channels x time x trials)
    %   3. Extract time vector from EEG.times
    %   4. Extract channel labels from EEG.chanlocs
    %   5. Extract stimulus event codes (triggers) for each epoch
    %   6. Recover original trial numbers via urevent mapping
    %   7. Save all variables to .mat file
    %
    % Original Trial Number Recovery:
    %   After pop_rejepoch() physically removes epochs, the original trial
    %   numbering is lost from the epoch indices. However, EEGLAB preserves
    %   the full original event table in EEG.urevent, and each remaining
    %   event retains its EEG.event(i).urevent index. This function:
    %     1. Finds all stimulus urevents in order (= original trials 1..N)
    %     2. For each surviving epoch, finds its time-locking event's urevent
    %     3. Maps that urevent to its position in the original sequence
    %   This recovers the original trial number for every retained epoch.
    %
    % Examples:
    %   % Extract results for a single subject
    %   config = default_config();
    %   [success, results] = extract_results('MC_05_08_1', config);
    %
    %   % Access extracted data
    %   erp = mean(results.data, 3);             % average ERP
    %   plot(results.time, erp(32, :));           % plot channel 32
    %   fprintf('Kept trials: %s\n', mat2str(results.trials));
    %
    %   % Load saved .mat file later
    %   results = load('output/06_final/MC_05_08_1-final.mat');
    %
    % Notes:
    %   - Requires final clean data from combine_markers() in 06_final/
    %   - Epochs are already physically removed; no rejection markers needed
    %   - Original trial numbers enable alignment with behavioral data
    %   - .mat file saved with -v7.3 for HDF5 compatibility
    %
    % See also: combine_markers, erplab_art_rej, eeg_epochs, default_config
    %
    % Author: Matt Kmiecik

    success = false;
    results = [];

    fprintf('=== EXTRACTING RESULTS FOR SUBJECT: %s ===\n', subject_id);

    try
        % Setup diary logging with timestamp
        log_dir = fullfile(config.dirs.logs, subject_id);
        if ~exist(log_dir, 'dir'), mkdir(log_dir); end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        diary(fullfile(log_dir, [subject_id '_extract_results_' timestamp '.txt']));

        %% LOAD FINAL CLEAN DATASET FROM 06_FINAL
        fprintf('  Loading final clean dataset...\n');
        final_filename = sprintf(config.naming.final, subject_id);
        EEG = pop_loadset('filename', [final_filename '.set'], ...
            'filepath', config.dirs.final);
        fprintf('  Data: %d channels x %d time points x %d trials\n', ...
            EEG.nbchan, EEG.pnts, EEG.trials);

        %% EXTRACT DATA MATRIX
        fprintf('  Extracting data matrix...\n');
        data = EEG.data; % channels x time_points x trials

        %% EXTRACT TIME VECTOR
        if isfield(EEG, 'times') && ~isempty(EEG.times)
            time = EEG.times / 1000; % ms to seconds
        else
            time = linspace(EEG.xmin, EEG.xmax, EEG.pnts);
        end
        fprintf('  Time: %.3f to %.3f s (%d points)\n', time(1), time(end), length(time));

        %% EXTRACT CHANNEL LABELS
        channels = {EEG.chanlocs.labels};

        %% EXTRACT TRIGGERS AND UREVENT INDICES PER EPOCH
        fprintf('  Extracting triggers...\n');
        triggers = zeros(1, EEG.trials);
        tl_urevents = zeros(1, EEG.trials);
        event_codes_num = cellfun(@str2double, config.event_codes);

        for i = 1:length(EEG.event)
            evt = EEG.event(i);
            if isnumeric(evt.type)
                evt_num = evt.type;
            else
                evt_num = str2double(evt.type);
            end
            if ~isnan(evt_num) && ismember(evt_num, event_codes_num)
                ep = evt.epoch;
                if triggers(ep) == 0 % first matching event per epoch
                    triggers(ep) = evt_num;
                    tl_urevents(ep) = evt.urevent;
                end
            end
        end

        %% RECOVER ORIGINAL TRIAL NUMBERS VIA UREVENT MAPPING
        fprintf('  Recovering original trial numbers...\n');

        % Find all stimulus urevents in original order = trials 1..N
        all_stim_urevents = zeros(1, length(EEG.urevent));
        count = 0;
        for i = 1:length(EEG.urevent)
            if isnumeric(EEG.urevent(i).type)
                ur_num = EEG.urevent(i).type;
            else
                ur_num = str2double(EEG.urevent(i).type);
            end
            if ~isnan(ur_num) && ismember(ur_num, event_codes_num)
                count = count + 1;
                all_stim_urevents(count) = i;
            end
        end
        all_stim_urevents = all_stim_urevents(1:count);
        fprintf('  Total original stimulus events (urevents): %d\n', count);

        % Map each epoch's time-locking urevent to its original trial position
        trials = zeros(1, EEG.trials);
        for i = 1:EEG.trials
            idx = find(all_stim_urevents == tl_urevents(i), 1);
            if ~isempty(idx)
                trials(i) = idx;
            else
                warning('Could not recover original trial number for epoch %d', i);
                trials(i) = NaN;
            end
        end
        fprintf('  Recovered trial numbers: %d to %d (of %d original)\n', ...
            min(trials), max(trials), length(all_stim_urevents));

        %% PACK RESULTS
        results = struct();
        results.data = data;
        results.time = time;
        results.channels = channels;
        results.trials = trials;
        results.triggers = triggers;

        %% SAVE .MAT FILE
        mat_filename = [final_filename '.mat'];
        mat_filepath = fullfile(config.dirs.final, mat_filename);
        fprintf('  Saving results to %s...\n', mat_filepath);
        save(mat_filepath, '-struct', 'results', '-v7.3');

        %% SUMMARY
        fprintf('=== EXTRACTION SUMMARY ===\n');
        fprintf('  Subject: %s\n', subject_id);
        fprintf('  Data shape: %d channels x %d time points x %d trials\n', ...
            size(data, 1), size(data, 2), size(data, 3));
        fprintf('  Time range: %.3f to %.3f s\n', time(1), time(end));
        fprintf('  Channels: %d\n', length(channels));
        fprintf('  Original trials retained: %d / %d\n', ...
            EEG.trials, length(all_stim_urevents));
        fprintf('  Output: %s\n', mat_filepath);

        success = true;
        fprintf('  Extraction completed successfully for %s\n', subject_id);
        diary off;

    catch ME
        fprintf('  ERROR in extract_results for %s: %s\n', subject_id, ME.message);
        fprintf('  Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        diary off;
        rethrow(ME);
    end
end
