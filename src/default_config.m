function config = default_config()
    % DEFAULT_CONFIG - Centralized configuration management for EEG processing pipeline
    %
    % DEFAULT_CONFIG creates a comprehensive configuration structure containing
    % all parameters, paths, and settings for the stage-based EEG preprocessing
    % pipeline. Provides centralized management of processing parameters,
    % directory organization, naming conventions, and quality control settings.
    %
    % Syntax: 
    %   config = default_config()
    %
    % Inputs:
    %   None
    %
    % Outputs:
    %   config - Comprehensive configuration structure containing:
    %            .main_dir      - Project root directory (current working directory)
    %            .data_dir      - Raw data directory (data/)
    %            .doc_dir       - Documentation directory (doc/)
    %            .output_dir    - Main output directory (output/)
    %            .eeglab_dir    - EEGLAB installation path (auto-detected)
    %            .erplab_dir    - ERPLAB plugin path
    %            .dirs          - Stage-based output directories
    %            .naming        - Standardized filename patterns
    %            .cleanline     - Line noise removal parameters
    %            .ica_rejection - ICA component rejection thresholds
    %            .erplab_art_rej - ERPLAB artifact rejection parameters
    %            Processing parameters and quality control options
    %
    % Stage-Based Directory Structure:
    %   .dirs.preprocessed        - output/02_preprocessed/
    %   .dirs.ica                 - output/03_ica/
    %   .dirs.components_rejected - output/04_components_rejected/
    %   .dirs.epoched             - output/05_epoched/
    %   .dirs.artifacts_rejected  - output/06_artifacts_rejected/
    %   .dirs.final               - output/07_final/
    %   .dirs.quality_control     - output/quality_control/
    %   .dirs.logs                - output/logs/
    %   .dirs.derivatives         - output/derivatives/
    %
    % File Naming Conventions:
    %   EEGLAB Pipeline:
    %     preprocessed_01hz: '[subject]-prepro'
    %     preprocessed_1hz:  '[subject]-prepro-1Hz'
    %     ica:              '[subject]-ica-1Hz'
    %     components_rejected: '[subject]-clean'
    %     epoched:          '[subject]-epochs'
    %     artifacts_rejected: '[subject]-art-rej'
    %
    %   ERPLAB Pipeline:
    %     preprocessed_erplab:      '[subject]-prepro-erplab'
    %     epoched_erplab:           '[subject]-epochs-erplab'
    %     artifacts_rejected_erplab: '[subject]-art-rej-erplab'
    %
    % Processing Parameters:
    %   Channel Configuration:
    %     - external_channels: EXG1-8 (removed during preprocessing)
    %     - channels_to_keep: A1-32, B1-32 (64-channel standard montage)
    %     - reference_channels: [24 61] (average mastoids)
    %
    %   Temporal Parameters:
    %     - sampling_rate: 256 Hz (target after resampling)
    %     - highpass_01hz: 0.1 Hz (EEGLAB epoching filter)
    %     - highpass_1hz: 1 Hz (EEGLAB ICA filter)
    %     - epoch_window: [-0.2 1] s (200ms pre, 1000ms post)
    %     - baseline_window: [-0.2 0] s (pre-stimulus baseline)
    %     - amplitude_threshold: 100 µV (EEGLAB artifact rejection)
    %
    %   Event Codes:
    %     - event_codes: {'111','112','221','222'} (stimulus/response events)
    %
    % ERPLAB Artifact Rejection:
    %   Advanced 5-step detection with configurable thresholds:
    %   - extreme_values_threshold: ±100 µV
    %   - peak_to_peak_threshold: ±75 µV (200ms windows, 100ms steps)
    %   - step_threshold: ±60 µV (250ms windows, 20ms steps)
    %   - trend detection: slope >75, R² >0.3
    %   - flatline detection: 0 µV threshold
    %
    % CleanLine Parameters:
    %   Optimized for 60Hz US line noise removal:
    %   - linefreqs: 60 Hz target frequency
    %   - bandwidth: 2 Hz removal bandwidth
    %   - winsize: 4 s analysis windows
    %   - winstep: 1 s window overlap
    %   - Additional parameters for signal detection and processing
    %
    % ICA Component Rejection:
    %   ICLabel probability thresholds:
    %   - muscle_threshold: 0.8 (muscle artifact rejection)
    %   - eye_threshold: 0.8 (eye artifact rejection)
    %   - Brain components preserved (NaN thresholds)
    %
    % Examples:
    %   % Get default configuration
    %   config = default_config();
    %
    %   % Use with preprocessing
    %   [success, EEG_01, EEG_1] = eeg_prepro('elaine', config);
    %
    %   % Use with ERPLAB workflow
    %   [success, EEG] = erplab_prepro('jerry', config);
    %   [success, EEG] = erplab_art_rej('jerry', config);
    %
    %   % Setup directories
    %   setup_output_directories(config);
    %
    %   % Modify parameters
    %   config.amplitude_threshold = 75; % Change threshold
    %   config.erplab_art_rej.extreme_values_threshold = 80;
    %
    % Quality Control Options:
    %   - enable_quality_control: true (run QC assessments)
    %   - generate_reports: true (create visual QC plots)
    %   - save_intermediate_files: true (save processing stages)
    %   - create_directories: true (auto-create output structure)
    %
    % Path Detection:
    %   - Automatically detects EEGLAB installation path
    %   - Sets ERPLAB path based on EEGLAB plugin directory
    %   - Uses current working directory as project root
    %   - May require manual ERPLAB path adjustment for custom installations
    %
    % Notes:
    %   - Central configuration ensures consistency across all functions
    %   - Supports both EEGLAB and ERPLAB processing workflows
    %   - Parameters optimized for 64-channel EEG with 256Hz sampling
    %   - Paths assume standard project directory structure
    %   - Easily customizable for different experimental setups
    %
    % See also: setup_output_directories, eeg_prepro, erplab_prepro, apply_cleanline_to_eeg
    %
    % Author: Matt Kmiecik
    
    config = struct();
    
    %% BASE PATHS
    config.main_dir = pwd();
    config.data_dir = fullfile(config.main_dir, 'data');
    config.doc_dir = fullfile(config.main_dir, 'doc');
    config.output_dir = fullfile(config.main_dir, 'output');
    
    %% TOOLBOX PATHS
    config.eeglab_dir = fileparts(which('eeglab')); % assumes already installed!
    config.erplab_dir = fullfile(config.eeglab_dir, 'plugins', 'ERPLAB12.01'); % may need updating
  
    %% STAGE-BASED OUTPUT DIRECTORIES
    config.dirs = struct();
    config.dirs.base = config.output_dir;
    config.dirs.preprocessed = fullfile(config.output_dir, '01_preprocessed');
    config.dirs.ica = fullfile(config.output_dir, '02_ica');
    config.dirs.components_rejected = fullfile(config.output_dir, '03_components_rejected');
    config.dirs.epoched = fullfile(config.output_dir, '04_epoched');
    config.dirs.artifacts_rejected = fullfile(config.output_dir, '05_artifacts_rejected');
    config.dirs.final = fullfile(config.output_dir, '06_final');
    config.dirs.logs = fullfile(config.output_dir, 'logs');
    config.dirs.pipeline_logs = fullfile(config.output_dir, 'logs', 'pipeline');
    
    %% FILE NAMING CONVENTIONS
    config.naming = struct();
    config.naming.preprocessed_01hz = '%s-prepro';                  % sub001-prepro
    config.naming.preprocessed_1hz = '%s-prepro-1Hz';               % sub001-prepro-1Hz
    config.naming.preprocessed_erplab = '%s-prepro-erplab';         % sub001-prepro-erplab  
    config.naming.ica = '%s-ica-1Hz';                               % sub001-ica-1Hz
    config.naming.components_rejected = '%s-clean';                 % sub001-clean
    config.naming.epoched = '%s-epochs';                            % sub001-epochs
    config.naming.epoched_erplab = '%s-epochs-erplab';              % sub001-epochs-erplab
    config.naming.artifacts_rejected = '%s-art-rej';                % sub001-art-rej
    config.naming.artifacts_rejected_erplab = '%s-art-rej-erplab';  % sub001-art-rej-erplab
    config.naming.final = '%s-final';                               % sub001-final
    
    %% PROCESSING PARAMETERS (same as before)
    config.external_channels = {'EXG1', 'EXG2', 'EXG3','EXG4','EXG5','EXG6','EXG7','EXG8'};
    
    % Generate A and B channel lists
    N = 32;
    A_chans = cell(1, N);
    B_chans = A_chans;
    for j = 1:N
        A_chans{j} = strcat('A', num2str(j));
        B_chans{j} = strcat('B', num2str(j));
    end
    config.channels_to_keep = [A_chans B_chans];
    
    config.sampling_rate = 256;
    config.reference_channels = [24 61]; % avg. mastoid ref
    config.highpass_01hz = 0.1;
    config.highpass_1hz = 1;
    
    config.event_codes = {'11', '22'}; % {'111','112','221','222'};
    config.epoch_window = [-0.2 0.25]; % epoch window
    config.baseline_window = [-0.2 0]; % baseline correction
    config.amplitude_threshold = 100; % uV threshold
    
    %% ICA COMPONENT REJECTION THRESHOLDS
    config.ica_rejection = struct();
    config.ica_rejection.muscle_threshold = 0.8;  % Muscle artifact probability threshold
    config.ica_rejection.eye_threshold = 0.8;     % Eye artifact probability threshold
    
    %% CLEANLINE PARAMETERS
    config.cleanline = struct();
    config.cleanline.bandwidth = 2;
    config.cleanline.linefreqs = 60;
    config.cleanline.normSpectrum = 0;
    config.cleanline.p = 0.01;
    config.cleanline.pad = 2;
    config.cleanline.plotfigures = 0;
    config.cleanline.scanforlines = 1;
    config.cleanline.sigtype = 'Channels';
    config.cleanline.tau = 100;
    config.cleanline.verb = 1;
    config.cleanline.winsize = 4;
    config.cleanline.winstep = 1;
    
    %% ERPLAB ARTIFACT REJECTION PARAMETERS
    config.erplab_art_rej = struct();
    
    % Resample and filter parameters
    config.erplab_art_rej.resample_rate = 256;
    config.erplab_art_rej.highpass_filter = 0.01;
    config.erplab_art_rej.lowpass_filter = 30;
    
    % Epoching parameters
    config.erplab_art_rej.epoch_window = [-0.2 0.25];  % ERPLAB epoch window
    config.erplab_art_rej.baseline_window = [-0.2 0];  % ERPLAB baseline
    
    % Artifact rejection thresholds
    config.erplab_art_rej.extreme_values_threshold = 100;   % ±100 µV
    config.erplab_art_rej.peak_to_peak_threshold = 75;      % ±75 µV
    config.erplab_art_rej.peak_to_peak_window_size = 200;   % 200ms
    config.erplab_art_rej.peak_to_peak_window_step = 100;   % 100ms
    config.erplab_art_rej.step_threshold = 60;              % ±60 µV
    config.erplab_art_rej.step_window_size = 250;           % 250ms
    config.erplab_art_rej.step_window_step = 20;            % 20ms
    config.erplab_art_rej.trend_min_slope = 75;             % minimum slope
    config.erplab_art_rej.trend_min_r2 = 0.3;               % minimum R²
    
    
    %% OPTIONS
    config.save_intermediate_files = true;
    config.create_directories = true;  % Auto-create output directories
end