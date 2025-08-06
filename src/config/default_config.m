% FILE: src/config/default_config.m (Updated with stage-based directories)

function config = default_config()
    % DEFAULT_CONFIG - Configuration with stage-based output directories
    
    config = struct();
    
    %% BASE PATHS
    config.main_dir = pwd();
    config.data_dir = fullfile(config.main_dir, 'data');
    config.doc_dir = fullfile(config.main_dir, 'doc');
    
    % Base output directory
    config.output_dir = fullfile(config.main_dir, 'output');
    
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
    config.naming.preprocessed_01hz = '%s-prepro';           % sub001-prepro
    config.naming.preprocessed_1hz = '%s-prepro-1Hz';       % sub001-prepro-1Hz  
    config.naming.ica = '%s-ica-1Hz';                       % sub001-ica-1Hz
    config.naming.components_rejected = '%s-clean';         % sub001-clean
    config.naming.epoched = '%s-epochs';                    % sub001-epochs
    config.naming.artifacts_rejected = '%s-epochs-clean';   % sub001-epochs-clean
    config.naming.final = '%s-final';                       % sub001-final
    
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
    config.reference_channels = [24 61];
    config.highpass_01hz = 0.1 * 2;
    config.highpass_1hz = 1 * 2;
    
    config.event_codes = {'111','112','221','222'};
    config.epoch_window = [-0.2 3];
    config.baseline_window = [-0.2 0];
    config.amplitude_threshold = 100;
    
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
    
    %% OPTIONS
    config.enable_quality_control = true;
    config.generate_reports = true;
    config.save_intermediate_files = true;
    config.create_directories = true;  % Auto-create output directories
end