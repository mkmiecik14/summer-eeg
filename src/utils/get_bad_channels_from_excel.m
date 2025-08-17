function bad_channels = get_bad_channels_from_excel(subject_id, config)
    % GET_BAD_CHANNELS_FROM_EXCEL - Extract bad channel information from Excel database
    %
    % GET_BAD_CHANNELS_FROM_EXCEL loads participant information from the Excel
    % database (ss-info.xlsx) and extracts bad channel indices for the specified
    % subject. This function handles various data formats and provides robust
    % error handling for missing or malformed channel information.
    %
    % Syntax: 
    %   bad_channels = get_bad_channels_from_excel(subject_id, config)
    %
    % Inputs:
    %   subject_id - String, subject identifier (e.g., 'elaine')
    %   config     - Configuration structure from default_config() containing:
    %                .doc_dir - Path to documentation directory with ss-info.xlsx
    %
    % Outputs:
    %   bad_channels - Vector of bad channel indices (e.g., [5 12 31])
    %                  Returns empty array [] if no bad channels found
    %
    % Excel File Format:
    %   Column 1: Subject IDs (string identifiers)
    %   Column 2: Bad channel information (various formats supported):
    %             - Numeric array: [5 12 31]
    %             - String format: "5 12 31" or "5,12,31"
    %             - Empty/NaN: No bad channels
    %
    % Error Handling:
    %   - Returns empty array and warning if subject not found
    %   - Returns empty array and warning if Excel file cannot be read
    %   - Handles both string and numeric bad channel specifications
    %   - Gracefully processes empty or NaN entries
    %
    % Example:
    %   % Get bad channels for subject preprocessing
    %   config = default_config();
    %   bad_chans = get_bad_channels_from_excel('jerry', config);
    %   if ~isempty(bad_chans)
    %       EEG = pop_select(EEG, 'nochannel', bad_chans);
    %   end
    %
    % Notes:
    %   - Automatically converts string representations to numeric arrays
    %   - Prints found bad channels to console for verification
    %   - Used during preprocessing to exclude problematic channels
    %   - Excel file must be in documentation directory specified by config
    %
    % See also: xlsread, default_config, pop_select, eeg_prepro
    %
    % Author: Matt Kmiecik

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