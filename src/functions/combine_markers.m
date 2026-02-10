function [success, EEG] = combine_markers(subject_id, config)
    % COMBINE_MARKERS - Merge EEGLAB and ERPLAB rejection markers and reject epochs
    %
    % COMBINE_MARKERS loads epoched datasets from both the EEGLAB and ERPLAB
    % artifact rejection pipelines, combines their rejection markers using a
    % logical OR (any trial flagged by either pipeline is rejected), physically
    % removes the marked epochs, and saves the final clean dataset. This
    % ensures that only epochs passing both pipelines' quality criteria are
    % retained for analysis.
    %
    % Syntax:
    %   [success, EEG] = combine_markers(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'MC_05_08_1')
    %   config     - Configuration structure from default_config() containing:
    %                .dirs.epoched   - Directory with epoched datasets
    %                .dirs.final     - Output directory for final clean data
    %                .dirs.logs      - Log file directory
    %                .naming.epoched_erplab - ERPLAB epoched filename pattern
    %                .naming.epoched        - EEGLAB epoched filename pattern
    %                .naming.final          - Final output filename pattern
    %
    % Outputs:
    %   success - Logical, true if processing completed successfully
    %   EEG     - Final EEGLAB EEG structure with rejected epochs removed
    %
    % Processing Pipeline:
    %   1. Load ERPLAB epoched data (with rejmanual markers)
    %   2. Load EEGLAB epoched data (with rejthresh markers)
    %   3. Validate both datasets have equal trial counts
    %   4. Extract rejection vectors from each dataset
    %   5. Combine via logical OR (reject if flagged by either pipeline)
    %   6. Report per-pipeline counts, overlap, and total rejections
    %   7. Physically remove flagged epochs using pop_rejepoch()
    %   8. Save final clean dataset to 06_final/
    %
    % Rejection Logic:
    %   - ERPLAB markers read from EEG.reject.rejmanual
    %   - EEGLAB markers read from EEG.reject.rejthresh
    %   - Combined with logical OR: trial rejected if flagged by either
    %   - Overlap count reported for transparency
    %
    % Examples:
    %   % Run for a single subject
    %   config = default_config();
    %   [success, EEG] = combine_markers('MC_05_08_1', config);
    %
    %   % Use after both pipelines have produced epoched data
    %   [s1, ~] = erplab_art_rej('MC_05_08_1', config);   % produces epochs-erplab
    %   [s2, ~] = eeg_epochs('MC_05_08_1', config);       % produces epochs
    %   [s3, EEG] = combine_markers('MC_05_08_1', config); % merges and saves final
    %
    % Input Files:
    %   - ERPLAB: output/04_epoched/[subject]-epochs-erplab.set
    %   - EEGLAB: output/04_epoched/[subject]-epochs.set
    %
    % Output Files:
    %   - Final clean data: output/06_final/[subject]-final.set
    %   - Log file: output/logs/[subject]/[subject]_combine_markers_[timestamp].txt
    %
    % Error Handling:
    %   - Trial count mismatch between datasets raises an error
    %   - Comprehensive error logging with stack traces via diary
    %   - Errors are rethrown after logging for batch processing compatibility
    %
    % Notes:
    %   - Requires both EEGLAB and ERPLAB epoched datasets to exist
    %   - The EEGLAB dataset is used as the base for the final output
    %   - Epochs are physically removed, not just flagged
    %   - Gracefully handles cases where one or both pipelines found no artifacts
    %
    % See also: erplab_art_rej, eeg_epochs, pop_rejepoch, default_config
    %
    % Author: Matt Kmiecik

    success = false;
    EEG = [];

    fprintf('=== COMBINING REJECTION MARKERS FOR SUBJECT: %s ===\n', subject_id);

    try
        %% SET UP
        % Setup diary logging with timestamp
        log_dir = fullfile(config.dirs.logs, subject_id);
        if ~exist(log_dir, 'dir'), mkdir(log_dir); end
        timestamp = datestr(now, 'yyyymmdd_HHMMSS');
        diary(fullfile(log_dir, [subject_id '_combine_markers_' timestamp '.txt']));

        %% LOAD EPOCHED EEG DATA
        fprintf('  Loading epoched EEG data...\n');

        % Load ERPLAB epoched data (with rejection markers)
        epoched_dir = config.dirs.epoched;
        filename = sprintf(config.naming.epoched_erplab, subject_id);
        file = fullfile(epoched_dir, [filename '.set']);
        EEG_erplab = pop_loadset(file);

        % Load EEGLAB epoched data (with rejection markers)
        filename = sprintf(config.naming.epoched, subject_id);
        file = fullfile(epoched_dir, [filename '.set']);
        EEG_eeglab = pop_loadset(file);

        %% EXTRACT REJECTION MARKERS
        fprintf('  Extracting rejection markers...\n');

        % Validates that both files have the same number of trials
        if EEG_erplab.trials ~= EEG_eeglab.trials
            error('Both files have different number of trials. Script terminated.');
        end

        initial_trials = EEG_eeglab.trials;

        % Initialize rejected_trials as empty logical vector
        erp_rej_trials = false(1, EEG_erplab.trials);
        eeg_rej_trials = false(1, EEG_eeglab.trials);

        % Finds the ERPLAB trial rejections
        if isfield(EEG_erplab.reject, 'rejmanual') && ~isempty(EEG_erplab.reject.rejmanual)
            erp_rej_trials = logical(EEG_erplab.reject.rejmanual);
            fprintf('  Found %d trials marked for rejection (ERPLAB)\n', sum(erp_rej_trials));
        else
            fprintf('  No ERPLAB rejection markers found\n');
        end

        % Finds the EEGLAB trial rejections (EEGLAB uses rejthresh field)
        if isfield(EEG_eeglab.reject, 'rejthresh') && ~isempty(EEG_eeglab.reject.rejthresh)
            eeg_rej_trials = logical(EEG_eeglab.reject.rejthresh);
            fprintf('  Found %d trials marked for rejection (EEGLAB)\n', sum(eeg_rej_trials));
        else
            fprintf('  No EEGLAB rejection markers found\n');
        end

        %% COALESCE REJECTION MARKERS
        % Logical OR: reject any trial flagged by either pipeline
        combined_rej = erp_rej_trials | eeg_rej_trials;
        overlap_count = sum(erp_rej_trials & eeg_rej_trials);
        rejected_count = sum(combined_rej);

        fprintf('  Combined rejection summary:\n');
        fprintf('    ERPLAB rejections:  %d\n', sum(erp_rej_trials));
        fprintf('    EEGLAB rejections:  %d\n', sum(eeg_rej_trials));
        fprintf('    Overlap (both):     %d\n', overlap_count);
        fprintf('    Total unique:       %d / %d (%.1f%%)\n', ...
            rejected_count, initial_trials, (rejected_count / initial_trials) * 100);

        %% REJECT EPOCHS
        if any(combined_rej)
            % Apply combined markers to EEGLAB dataset
            EEG_eeglab.reject.rejmanual = combined_rej;
            fprintf('  Rejecting %d marked epochs...\n', rejected_count);
            EEG_eeglab = pop_rejepoch(EEG_eeglab, find(combined_rej), 0);
        else
            fprintf('  No epochs marked for rejection\n');
        end

        %% SAVE FINAL CLEAN DATA TO 06_FINAL
        fprintf('  Saving final clean data...\n');
        final_filename = sprintf(config.naming.final, subject_id);
        EEG_eeglab = pop_saveset(EEG_eeglab, 'filename', [final_filename '.set'], ...
            'filepath', config.dirs.final);

        %% FINAL REPORT
        final_trials = EEG_eeglab.trials;
        fprintf('  Final result:\n');
        fprintf('    Initial trials:  %d\n', initial_trials);
        fprintf('    Rejected trials: %d (%.1f%%)\n', rejected_count, (rejected_count / initial_trials) * 100);
        fprintf('    Final trials:    %d\n', final_trials);

        EEG = EEG_eeglab;
        success = true;
        fprintf('  Combine markers completed successfully for %s\n', subject_id);
        diary off;

    catch ME
        fprintf('  ERROR in combine_markers for %s: %s\n', subject_id, ME.message);
        fprintf('  Stack trace:\n');
        for k = 1:length(ME.stack)
            fprintf('    %s (line %d)\n', ME.stack(k).name, ME.stack(k).line);
        end
        diary off;
        rethrow(ME);
    end

end
