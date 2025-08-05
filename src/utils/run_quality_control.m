% FILE: src/utils/run_quality_control.m (Updated for stage-based organization)

function [EEG, quality_report] = run_quality_control(EEG, subject_id, config)
    % RUN_QUALITY_CONTROL - Comprehensive quality control assessment
    %
    % Performs quality control checks and generates reports with
    % stage-appropriate output locations.
    %
    % Syntax: [EEG, quality_report] = run_quality_control(EEG, subject_id, config)
    %
    % Inputs:
    %   EEG        - EEG structure to assess
    %   subject_id - String, subject identifier  
    %   config     - Configuration structure
    %
    % Outputs:
    %   EEG            - EEG structure (unchanged)
    %   quality_report - Structure with quality metrics

    quality_report = struct();
    quality_report.subject_id = subject_id;
    quality_report.timestamp = datetime('now');
    quality_report.processing_stage = 'preprocessing';
    
    fprintf('    Running quality control checks...\n');
    
    try
        %% BASIC DATA QUALITY METRICS
        quality_report.data_size = size(EEG.data);
        quality_report.sampling_rate = EEG.srate;
        quality_report.duration_seconds = EEG.pnts / EEG.srate;
        quality_report.n_channels = EEG.nbchan;
        
        %% AMPLITUDE STATISTICS
        data_flat = EEG.data(:);
        quality_report.amplitude.mean = mean(abs(data_flat));
        quality_report.amplitude.std = std(data_flat);
        quality_report.amplitude.max = max(abs(data_flat));
        quality_report.amplitude.min = min(abs(data_flat));
        quality_report.amplitude.range = range(data_flat);
        
        %% CHANNEL-WISE QUALITY
        channel_vars = var(EEG.data, 0, 2);
        quality_report.channels.variances = channel_vars;
        quality_report.channels.mean_variance = mean(channel_vars);
        quality_report.channels.std_variance = std(channel_vars);
        
        % Detect potentially problematic channels
        var_z_scores = zscore(channel_vars);
        quality_report.channels.high_variance = find(var_z_scores > 3);
        quality_report.channels.low_variance = find(var_z_scores < -3);
        quality_report.channels.flat_channels = find(channel_vars < 0.1);
        
        %% FREQUENCY DOMAIN ANALYSIS
        % Calculate power spectral density
        [psd, freqs] = pwelch(EEG.data', [], [], [], EEG.srate);
        
        % Power in different frequency bands
        delta_idx = freqs >= 1 & freqs <= 4;
        theta_idx = freqs >= 4 & freqs <= 8;
        alpha_idx = freqs >= 8 & freqs <= 13;
        beta_idx = freqs >= 13 & freqs <= 30;
        gamma_idx = freqs >= 30 & freqs <= 100;
        
        quality_report.power.delta = mean(mean(psd(delta_idx, :)));
        quality_report.power.theta = mean(mean(psd(theta_idx, :)));
        quality_report.power.alpha = mean(mean(psd(alpha_idx, :)));
        quality_report.power.beta = mean(mean(psd(beta_idx, :)));
        quality_report.power.gamma = mean(mean(psd(gamma_idx, :)));
        
        % Line noise assessment (around 60 Hz)
        line_noise_idx = freqs >= 58 & freqs <= 62;
        quality_report.power.line_noise = mean(mean(psd(line_noise_idx, :)));
        
        %% OVERALL QUALITY SCORE
        quality_score = 100; % Start with perfect score
        
        % Deduct points for problematic channels
        quality_score = quality_score - 5 * length(quality_report.channels.high_variance);
        quality_score = quality_score - 10 * length(quality_report.channels.flat_channels);
        
        % Deduct points for extreme amplitudes
        if quality_report.amplitude.max > 200
            quality_score = quality_score - 10;
        end
        
        % Deduct points for excessive line noise
        total_power = quality_report.power.delta + quality_report.power.theta + ...
                     quality_report.power.alpha + quality_report.power.beta;
        line_noise_ratio = quality_report.power.line_noise / total_power;
        if line_noise_ratio > 0.1  % More than 10% line noise
            quality_score = quality_score - 15;
        end
        
        quality_report.overall_score = max(0, quality_score);
        
        %% GENERATE QUALITY PLOT
        if config.generate_reports
            generate_quality_plot(EEG, quality_report, config);
        end
        
        fprintf('    Quality score: %.1f/100\n', quality_report.overall_score);
        
        if quality_report.overall_score < 70
            fprintf('    WARNING: Low quality score for %s\n', subject_id);
        end
        
    catch ME
        warning('Error in quality control for %s: %s', subject_id, ME.message);
        quality_report.error = ME.message;
        quality_report.overall_score = 0;
    end
end

function generate_quality_plot(EEG, quality_report, config)
    % Generate comprehensive quality control plot
    
    subject_id = quality_report.subject_id;
    
    fig = figure('Position', [100, 100, 1200, 800], 'Visible', 'off');
    
    % Plot 1: Channel variances
    subplot(2, 3, 1);
    bar(quality_report.channels.variances);
    title('Channel Variances');
    xlabel('Channel');
    ylabel('Variance');
    
    % Highlight problematic channels
    hold on;
    if ~isempty(quality_report.channels.high_variance)
        bar(quality_report.channels.high_variance, ...
            quality_report.channels.variances(quality_report.channels.high_variance), 'r');
    end
    if ~isempty(quality_report.channels.flat_channels)
        bar(quality_report.channels.flat_channels, ...
            quality_report.channels.variances(quality_report.channels.flat_channels), 'k');
    end
    hold off;
    
    % Plot 2: Power spectral density
    subplot(2, 3, 2);
    [psd, freqs] = pwelch(EEG.data', [], [], [], EEG.srate);
    semilogy(freqs, mean(psd, 2));
    title('Power Spectral Density');
    xlabel('Frequency (Hz)');
    ylabel('Power');
    xlim([0, 100]);
    
    % Plot 3: Sample EEG traces
    subplot(2, 3, 3);
    time_samples = 1:min(1000, EEG.pnts);  % First 1000 samples or all data
    time_sec = time_samples / EEG.srate;
    plot(time_sec, EEG.data(1:min(5, EEG.nbchan), time_samples)');
    title('Sample EEG Traces (First 5 Channels)');
    xlabel('Time (s)');
    ylabel('Amplitude (µV)');
    
    % Plot 4: Amplitude distribution
    subplot(2, 3, 4);
    histogram(EEG.data(:), 50);
    title('Amplitude Distribution');
    xlabel('Amplitude (µV)');
    ylabel('Count');
    
    % Plot 5: Quality metrics summary
    subplot(2, 3, 5);
    metrics = [quality_report.power.delta, quality_report.power.theta, ...
               quality_report.power.alpha, quality_report.power.beta, ...
               quality_report.power.gamma];
    bar(metrics);
    set(gca, 'XTickLabel', {'Delta', 'Theta', 'Alpha', 'Beta', 'Gamma'});
    title('Power by Frequency Band');
    ylabel('Power');
    
    % Plot 6: Overall summary
    subplot(2, 3, 6);
    text(0.1, 0.8, sprintf('Subject: %s', subject_id), 'FontSize', 12, 'FontWeight', 'bold');
    text(0.1, 0.7, sprintf('Quality Score: %.1f/100', quality_report.overall_score), 'FontSize', 11);
    text(0.1, 0.6, sprintf('Channels: %d', quality_report.n_channels), 'FontSize', 10);
    text(0.1, 0.5, sprintf('Duration: %.1f s', quality_report.duration_seconds), 'FontSize', 10);
    text(0.1, 0.4, sprintf('Max Amplitude: %.1f µV', quality_report.amplitude.max), 'FontSize', 10);
    text(0.1, 0.3, sprintf('Problematic Channels: %d', ...
        length(quality_report.channels.high_variance) + length(quality_report.channels.flat_channels)), 'FontSize', 10);
    axis off;
    
    sgtitle(sprintf('Quality Control Report: %s', subject_id), 'FontSize', 14, 'FontWeight', 'bold');
    
    % Save plot
    plot_file = fullfile(config.dirs.quality_control, 'plots', ...
        [subject_id '_quality_control.png']);
    saveas(fig, plot_file);
    close(fig);
    
    fprintf('    Quality plot saved: %s\n', [subject_id '_quality_control.png']);
end