% EEG ERP epochs
% Matt Kmiecik
% Started 2025-06-14
% Purpose: clean the EEG via ICA components and create epochs

run("src/workspace_prep.m") % Prepares workspace

% Initializes subjects for batch processing (if applicable)
ss = string({RAW{2:size(RAW,1),1}});
i=2; % for testing purposes

for i = 1:length(ss)
    
    % Creating variables ----
    this_ss = ss{i};
    this_ss_path_1Hz = dir(fullfile(output_dir, strcat(this_ss, '*-1Hz-ica.set')));
    this_ss_name_1Hz = this_ss_path_1Hz.name;

    % filepath for .01Hz data set
    this_ss_path = dir(fullfile(output_dir, strcat(this_ss, '-prepro.set')));
    this_ss_name = this_ss_path.name;

    % Loads ICA data set to get weights ----
    EEG_1Hz = pop_loadset('filename',this_ss_name_1Hz,'filepath', this_ss_path_1Hz.folder);
    EEG = pop_loadset('filename',this_ss_name,'filepath', this_ss_path.folder);
    EEG.icaweights  = EEG_1Hz.icaweights;
    EEG.icasphere   = EEG_1Hz.icasphere;
    EEG.icawinv     = EEG_1Hz.icawinv;
    EEG.chanlocs    = EEG_1Hz.chanlocs;     % Optional but recommended
    EEG.icachansind = EEG_1Hz.icachansind;  % Track channels used for ICA
    EEG.icaact      = [];                   % Let EEGLAB recompute if needed

    % Overwrite in memory (no prompt)
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG = eeg_checkset(EEG);  % silently check integrity

    % Labels ICs for rejection ----
    EEG = pop_iclabel(EEG, 'default');
    EEG = pop_icflag(EEG, ...
        [NaN NaN;...    % brain
        0.8 1;...       % muscle (> 80% probability will reject components)
        0.8 1;...       % eye (> 80% probability will reject components)
        NaN NaN;...     % heart
        NaN NaN;...     % line noise
        NaN NaN;...     % channel noise
        NaN NaN...      % other
        ]);

    % Removes artifactual ICs
    this_reject = find(EEG.reject.gcompreject);
    EEG = pop_subcomp(EEG, this_reject, 0);

    % creates epoched data
    EEG = pop_epoch(EEG, {'111','112','221','222'}, [-0.2 3]);

    % baseline correction
    EEG = pop_rmbase(EEG, [EEG.xmin 0]);  % remove mean baseline from -200 to 0 ms

    % Thresholding ----
    EEG = pop_eegthresh(EEG,1,[1:64] ,-100,100, EEG.xmin, EEG.xmax,0,0);
    [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEG, 1,'overwrite','on','gui','off');


end