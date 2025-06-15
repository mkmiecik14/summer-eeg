% EEG Preprocessing Pipeline Step 1
% Matt Kmiecik
% Started 2025-06-14

run("src/workspace_prep.m")

% Initializes subjects for batch processing (if applicable)
ss = string({RAW{2:size(RAW,1),1}});

i=2; % for testing purposes

% Preprocessing ----
for i = 1:length(ss)

    % Creating variables ----
    this_ss = ss{i};
    this_ss_path = dir(fullfile(data_dir, strcat(this_ss, '.bdf')));
    this_ss_name = this_ss_path.name;

    % Loads in raw data using biosemi ----
    EEG = pop_biosig(...
        fullfile(this_ss_path.folder, this_ss_name),...
        'ref', [1] ,...
        'refoptions',{'keepref','on'},...
        'importannot', 'off',... % does not import EDF annotations
        'bdfeventmode', 6 ... % this event mode syncs nicely with EMSE events
        );
        
    % Remove externals that are not being used ----
    EEG = pop_select(...
        EEG,...
        'rmchannel',{'EXG1', 'EXG2', 'EXG3','EXG4','EXG5','EXG6','EXG7','EXG8'}...
        );
    
    % Checks to see if there are more than 64 channels in the recording----
    % first creates a vector of the chan names   
    N = 32;
    A_chans = cell(1, N);
    B_chans = A_chans;
    for j=1:N
        A_chans{j} = strcat('A', num2str(j));
        B_chans{j} = strcat('B', num2str(j));
    end
    chans_to_keep = [A_chans B_chans]; % here is the vector of channel names
    
    % keeps these chans only
    if EEG.nbchan > 64
        EEG = pop_select(EEG, 'channel', chans_to_keep);
    else
        disp('only 64 channels detected; not removing any...');
    end
        
    % Configuring channel locations ----
    % loads rotated chanel locations
    % https://github.com/mkmiecik14/luc-stim/blob/main/nose_along_fix.m
    load(fullfile('doc', 'chan_info_nose_along_fixed.mat'));
    load(fullfile('doc', 'chan_locs_nose_along_fixed.mat'));
    EEG.chaninfo = chan_info; % sets new info
    EEG.chanlocs = chan_locs; % sets new locations

    % sets A1 as ref because it was chosen upon import
    EEG = pop_chanedit(EEG, 'setref', {'1:64' 'Fp1'}); 
    
    % Downsamples to 256Hz ----
    EEG = pop_resample(EEG, 256);
    
    % Re-references data to 
    EEG = pop_reref( EEG, [24 61] ,'keepref','on'); % linked mastoids
    
    % Removing DC offset by subtracting the mean signal from each electrode
    EEG = pop_rmbase(EEG, [], []);
    
    % Highpass filters at .01Hz for ERP data and 1Hz for ICA
    EEG = pop_eegfiltnew(EEG, 'locutoff', 0.1*2, 'plotfreqz', 0);
    EEG_1Hz = pop_eegfiltnew(EEG, 'locutoff', 1*2, 'plotfreqz', 0);

    % Cleanline ----
    % Removing electrical line noise @ 60 Hz
    EEG = pop_cleanline(EEG, 'bandwidth', 2, 'chanlist', [1:EEG.nbchan],...
        'computepower', 1, 'linefreqs', 60, 'normSpectrum', 0, ...
        'p', 0.01, 'pad', 2, 'plotfigures' , 0, 'scanforlines', 1, ...
        'sigtype', 'Channels', 'tau', 100, 'verb', 1, 'winsize', ...
        4,'winstep',1);

     EEG_1Hz = pop_cleanline(EEG_1Hz, 'bandwidth', 2, 'chanlist', [1:EEG_1Hz.nbchan],...
        'computepower', 1, 'linefreqs', 60, 'normSpectrum', 0, ...
        'p', 0.01, 'pad', 2, 'plotfigures' , 0, 'scanforlines', 1, ...
        'sigtype', 'Channels', 'tau', 100, 'verb', 1, 'winsize', ...
        4,'winstep',1);
    
    % Renames dataset ----

    % 0.1Hz data set
    dataset_name = strcat(this_ss, '-prepro');
    EEG = pop_editset(EEG, 'setname', dataset_name, 'run', []);

    % 1Hz data set
    dataset_name_1Hz = strcat(this_ss, '-1Hz-prepro');
    EEG = pop_editset(EEG_1Hz, 'setname', dataset_name_1Hz, 'run', []);

    % Saves out preprocessed data for inspection ----
    EEG = pop_saveset(EEG, 'filename', dataset_name, 'filepath', output_dir);
    EEG_1Hz = pop_saveset(EEG_1Hz, 'filename', dataset_name_1Hz, 'filepath', output_dir);

    % Overwrite in memory (no prompt)
    [ALLEEG, EEG, CURRENTSET] = eeg_store(ALLEEG, EEG, CURRENTSET);
    EEG = eeg_checkset(EEG);  % silently check integrity
    
    eeglab redraw % redraws to GUI for convenience

end