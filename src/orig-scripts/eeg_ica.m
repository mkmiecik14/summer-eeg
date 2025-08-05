% EEG ICA Step 2 (after visual inspection)
% Matt Kmiecik
% Started 2025-06-14

run("src/workspace_prep.m") % Prepares workspace

% Initializes subjects for batch processing (if applicable)
ss = string({RAW{2:size(RAW,1),1}});
i=2; % for testing purposes

for i = 1:length(ss)
    
    % Creating variables ----
    this_ss = ss{i};
    this_ss_path = dir(fullfile(output_dir, strcat(this_ss, '*-1Hz-prepro.set')));
    this_ss_name = this_ss_path.name;
    
    % Checks to see if the a visually inspected and rejected file exists
    % (i.e., if sections of the EEG were rejected due to noise)
    this_ss_vis_rej = strcat(num2str(this_ss), '-prepro-vis-rej.set');
    if isfile(fullfile(output_dir, this_ss_vis_rej))
     % File exists...load in the visually inspected and rejected file
     % Loads in raw data using EEGLAB ----
    EEG = pop_loadset('filename',this_ss_vis_rej,'filepath', this_ss_path.folder);
    else
     % File does not exist...load standard file
    % Loads in raw data using EEGLAB ----
    EEG = pop_loadset('filename',this_ss_name,'filepath', this_ss_path.folder);
    end
    
    % If there were any bad channels identified during inspection, they are
    % imported here:
    bad_chans = RAW{i+1,2}; % raw data from excel
    if isnan(bad_chans)
        interpchans = {}; % will handle blank cells; blank == no bad chans
    else 
        interpchans = str2num(RAW{i+1,2}); % gathers bad channels from excel
    end

    % Interpolates bad channels if bad channels were identified
    if sum(size(interpchans, 2)) > 0 % checks to see if there are bad channels
        disp('Bad channel(s) detected...interpolating channels...');
        EEG = pop_interp(EEG, interpchans, 'spherical');
    else
        disp('No bad channels detected...')
    end
    
    % ICA decomposition ---
    % calculates rank use w/ link mastoid
    this_rank = EEG.nbchan - length(interpchans) - 1; % -1 linked mast
    if this_rank ~= rank(double(EEG.data))
        disp('This participant is rank deficient...');
        disp(strcat('Skipping...', this_ss, '...'));
    else

        EEG = pop_runica(...
            EEG,...
            'icatype', 'runica',... 
            'extended',1,...
            'interrupt','on',...
            'pca',this_rank...
        );

        % renames dataset
        dataset_name = strcat(this_ss, '-1Hz-ica');
        EEG = pop_editset(EEG, 'setname', dataset_name, 'run', []);
    
        % Saves out data
        outname = strcat(dataset_name, '.set'); % save out subject name
        EEG = pop_saveset(EEG, 'filename', outname, 'filepath', output_dir);

    end
    
end

eeglab redraw