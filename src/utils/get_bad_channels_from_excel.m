% FILE: src/utils/get_bad_channels_from_excel.m (Updated for new config structure)

function bad_channels = get_bad_channels_from_excel(subject_id, config)
    % GET_BAD_CHANNELS_FROM_EXCEL - Load bad channel info from Excel file
    %
    % Loads participant information from ss-info.xlsx and extracts
    % bad channel information for the specified subject.
    %
    % Syntax: bad_channels = get_bad_channels_from_excel(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier
    %   config     - Configuration structure
    %
    % Outputs:
    %   bad_channels - Vector of bad channel indices, or empty if none

    try
        % Load participant information
        [NUM, TXT, RAW] = xlsread(fullfile(config.doc_dir, 'ss-info.xlsx'));
        
        % Find subject row
        subject_row = find(strcmp(RAW(:,1), subject_id));
        
        if isempty(subject_row)
            warning('Subject %s not found in Excel file', subject_id);
            bad_channels = [];
            return;
        end
        
        % Get bad channels from Excel 
        % assumes column 2 contains bad channel info
        bad_chan_data = RAW{subject_row, 2};
        
        if isempty(bad_chan_data) || (isnumeric(bad_chan_data) && all(isnan(bad_chan_data)))
            bad_channels = [];
        elseif ischar(bad_chan_data) || isstring(bad_chan_data)
            % Parse string of channel numbers
            bad_channels = str2num(bad_chan_data);
        else
            % Assume it's already numeric
            bad_channels = bad_chan_data;
        end
        
        if ~isempty(bad_channels)
            fprintf('    Found %d bad channels: %s\n', length(bad_channels), ...
                mat2str(bad_channels));
        end
        
    catch ME
        warning('Error reading bad channels for %s: %s', subject_id, ME.message);
        bad_channels = [];
    end
end