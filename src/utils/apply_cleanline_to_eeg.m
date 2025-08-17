function EEG = apply_cleanline_to_eeg(EEG, config)
    % APPLY_CLEANLINE_TO_EEG - Remove line noise using CleanLine algorithm
    %
    % APPLY_CLEANLINE_TO_EEG removes 60Hz line noise and harmonics from EEG
    % data using the CleanLine plugin. This wrapper function ensures consistent
    % parameter application across all datasets using centralized configuration.
    %
    % Syntax: 
    %   EEG = apply_cleanline_to_eeg(EEG, config)
    %
    % Inputs:
    %   EEG    - EEGLAB EEG structure containing continuous or epoched data
    %   config - Configuration structure from default_config() containing:
    %            .cleanline.bandwidth     - Bandwidth for line noise removal (Hz)
    %            .cleanline.linefreqs     - Frequencies to target (e.g., [60 120])
    %            .cleanline.normSpectrum  - Normalize spectrum (0 or 1)
    %            .cleanline.p             - Significance level for detection
    %            .cleanline.pad           - Padding factor for FFT
    %            .cleanline.plotfigures   - Show diagnostic plots (0 or 1)
    %            .cleanline.scanforlines  - Scan for line frequencies (0 or 1)
    %            .cleanline.sigtype       - Signal type ('EEG' or 'MEG')
    %            .cleanline.tau           - Window overlap factor
    %            .cleanline.verb          - Verbose output (0 or 1)
    %            .cleanline.winsize       - Window size in seconds
    %            .cleanline.winstep       - Window step size in seconds
    %
    % Outputs:
    %   EEG - EEGLAB EEG structure with line noise removed
    %
    % Algorithm:
    %   CleanLine uses multi-taper spectral analysis to identify and remove
    %   line noise while preserving the underlying neural signal. It operates
    %   on overlapping windows and can handle both continuous and epoched data.
    %
    % Example:
    %   % Remove 60Hz line noise from preprocessed data
    %   config = default_config();
    %   EEG = apply_cleanline_to_eeg(EEG, config);
    %
    % Notes:
    %   - Typically applied during preprocessing stage before ICA
    %   - Works on all channels simultaneously
    %   - Can target multiple line frequencies (60Hz, 120Hz, etc.)
    %   - Parameters are optimized for 60Hz US power line noise
    %
    % See also: pop_cleanline, default_config, eeg_prepro
    %
    % Reference: 
    %   Mullen, T. (2012). CleanLine EEGLAB plugin. 
    %   Available from: https://github.com/sccn/cleanline
    %
    % Author: Matt Kmiecik

    EEG = pop_cleanline(EEG, ...
        'bandwidth', config.cleanline.bandwidth, ...
        'chanlist', [1:EEG.nbchan], ...
        'computepower', 1, ...
        'linefreqs', config.cleanline.linefreqs, ...
        'normSpectrum', config.cleanline.normSpectrum, ...
        'p', config.cleanline.p, ...
        'pad', config.cleanline.pad, ...
        'plotfigures', config.cleanline.plotfigures, ...
        'scanforlines', config.cleanline.scanforlines, ...
        'sigtype', config.cleanline.sigtype, ...
        'tau', config.cleanline.tau, ...
        'verb', config.cleanline.verb, ...
        'winsize', config.cleanline.winsize, ...
        'winstep', config.cleanline.winstep);
end