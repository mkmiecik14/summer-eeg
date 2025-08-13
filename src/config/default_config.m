% FILE: src/config/default_config.m (Updated with stage-based directories)

function config = default_config()
    % DEFAULT_CONFIG - Configuration with stage-based output directories
    
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
    config.dirs.raw = fullfile(config.output_dir, '01_raw');
    config.dirs.preprocessed = fullfile(config.output_dir, '02_preprocessed');
    config.dirs.ica = fullfile(config.output_dir, '03_ica');
    config.dirs.components_rejected = fullfile(config.output_dir, '04_components_rejected');
    config.dirs.epoched = fullfile(config.output_dir, '05_epoched');
    config.dirs.artifacts_rejected = fullfile(config.output_dir, '06_artifacts_rejected');
    config.dirs.final = fullfile(config.output_dir, '07_final');
    config.dirs.quality_control = fullfile(config.output_dir, 'quality_control');
    config.dirs.logs = fullfile(config.output_dir, 'logs');
    config.dirs.derivatives = fullfile(config.output_dir, 'derivatives');
    
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
    
    config.event_codes = {'111','112','221','222'};
    config.epoch_window = [-0.2 1.5]; % epoch window
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
    config.erplab_art_rej.epoch_window = [-0.2 1.5];  % -200ms to 1500ms
    config.erplab_art_rej.baseline_window = [-0.2 0];  % -200ms to 0ms
    
    % Artifact rejection thresholds
    config.erplab_art_rej.extreme_values_threshold = 100;  % ±100 µV
    config.erplab_art_rej.peak_to_peak_threshold = 75;     % ±75 µV
    config.erplab_art_rej.peak_to_peak_window_size = 200;  % 200ms
    config.erplab_art_rej.peak_to_peak_window_step = 100;  % 100ms
    config.erplab_art_rej.step_threshold = 60;             % ±60 µV
    config.erplab_art_rej.step_window_size = 250;          % 250ms
    config.erplab_art_rej.step_window_step = 20;           % 20ms
    config.erplab_art_rej.trend_min_slope = 75;            % minimum slope
    config.erplab_art_rej.trend_min_r2 = 0.3;             % minimum R²
    
    
    %% OPTIONS
    config.enable_quality_control = true;
    config.generate_reports = true;
    config.save_intermediate_files = true;
    config.create_directories = true;  % Auto-create output directories
end