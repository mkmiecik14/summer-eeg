function setup_output_directories(config)
    % SETUP_OUTPUT_DIRECTORIES - Initialize complete stage-based directory structure
    %
    % SETUP_OUTPUT_DIRECTORIES creates the comprehensive directory structure
    % required for the stage-based EEG processing pipeline. Automatically
    % creates all processing stage directories, logging subdirectories, and
    % quality control organization with detailed progress reporting.
    %
    % Syntax: 
    %   setup_output_directories(config)
    %
    % Inputs:
    %   config - Configuration structure from default_config() containing:
    %            .dirs - Directory path structure with all processing stages:
    %                    .preprocessed, .ica, .components_rejected,
    %                    .epoched, .artifacts_rejected, .final,
    %                    .logs, .quality_control
    %
    % Outputs:
    %   None (creates directories on filesystem)
    %
    % Created Directory Structure:
    %   Processing Stages:
    %     output/02_preprocessed/       - Filtered, re-referenced data
    %     output/03_ica/                - ICA decomposition results
    %     output/04_components_rejected/- Post-component rejection data
    %     output/05_epoched/            - Event-segmented data
    %     output/06_artifacts_rejected/ - Final clean epochs
    %     output/07_final/              - Analysis-ready datasets
    %
    %   Logging Infrastructure:
    %     output/logs/error_logs/       - Error and exception logs
    %     output/logs/performance_logs/ - Processing time and metrics
    %     output/logs/by_date/          - Date-organized log files
    %     output/logs/by_subject/       - Subject-specific logs
    %
    %   Quality Control:
    %     output/quality_control/individual_reports/ - Per-subject QC reports
    %     output/quality_control/summary_reports/    - Batch processing summaries
    %     output/quality_control/plots/              - QC visualization plots
    %
    % Features:
    %   - Checks for existing directories before creation
    %   - Provides detailed creation vs. existing status for each directory
    %   - Creates hierarchical subdirectory structure automatically
    %   - Safe to run multiple times (idempotent operation)
    %   - Progress reporting with clear status messages
    %
    % Example:
    %   % Initialize directory structure for new environment
    %   config = default_config();
    %   setup_output_directories(config);
    %
    %   % Use in pipeline initialization
    %   fprintf('Initializing processing environment...\n');
    %   setup_output_directories(config);
    %   fprintf('Ready to begin processing.\n');
    %
    % Directory Creation Status:
    %   - "Created:" indicates new directory was made
    %   - "Exists:"  indicates directory was already present
    %   - Summary confirmation message at completion
    %
    % Notes:
    %   - Essential first step for any new processing environment
    %   - Automatically called by main pipeline scripts
    %   - Creates both data storage and organizational directories
    %   - Supports both local and network storage locations
    %   - No data modification - only directory structure creation
    %
    % See also: default_config, mkdir, run_pipeline_staged
    %
    % Author: Matt Kmiecik

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