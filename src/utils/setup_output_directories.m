% FILE: src/utils/setup_output_directories.m

function setup_output_directories(config)
    % SETUP_OUTPUT_DIRECTORIES - Create all necessary output directories
    %
    % Creates the full directory structure for stage-based processing
    % if it doesn't already exist.
    %
    % Syntax: setup_output_directories(config)
    %
    % Inputs:
    %   config - Configuration structure with dirs field
    %
    % Example:
    %   config = default_config();
    %   setup_output_directories(config);

    fprintf('Setting up output directory structure...\n');
    
    % Get all directory fields
    dir_fields = fieldnames(config.dirs);
    
    % Create each directory if it doesn't exist
    for i = 1:length(dir_fields)
        dir_path = config.dirs.(dir_fields{i});
        
        if ~exist(dir_path, 'dir')
            mkdir(dir_path);
            fprintf('  Created: %s\n', dir_path);
        else
            fprintf('  Exists:  %s\n', dir_path);
        end
    end
    
    % Create subdirectories for logs
    log_subdirs = {'error_logs', 'performance_logs', 'by_date', 'by_subject'};
    for i = 1:length(log_subdirs)
        subdir_path = fullfile(config.dirs.logs, log_subdirs{i});
        if ~exist(subdir_path, 'dir')
            mkdir(subdir_path);
            fprintf('  Created: %s\n', subdir_path);
        end
    end
    
    % Create QC subdirectories
    qc_subdirs = {'individual_reports', 'summary_reports', 'plots'};
    for i = 1:length(qc_subdirs)
        subdir_path = fullfile(config.dirs.quality_control, qc_subdirs{i});
        if ~exist(subdir_path, 'dir')
            mkdir(subdir_path);
            fprintf('  Created: %s\n', subdir_path);
        end
    end
    
    fprintf('Directory setup complete.\n');
end