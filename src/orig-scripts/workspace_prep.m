% Workspace Preparation
% This script is meant to be run at the beginning of each script in this
% project to prepare MATLAB with paths and other code that is redundant in
% each script
%
% Matt Kmiecik
%
% Started 2025-06-14

% Sets working directory ----
% creating the main dir 
main_dir = '/Users/mattk/Library/CloudStorage/GoogleDrive-mkmiecik14@gmail.com/My Drive/projects/summer-eeg'; 
cd(main_dir); % setting the working directory

% Directory paths ----
data_dir = fullfile(main_dir, 'data'); % creating the data folder
output_dir = fullfile(main_dir, 'output'); % creating the output dir

% Starts EEGLAB ----
[ALLEEG, EEG, CURRENTSET, ALLCOM] = eeglab;

% Loads in participant information ----
[NUM,TXT,RAW] = xlsread(fullfile('doc', 'ss-info.xlsx'));

% Global vars ----
% I created this montage using the XYZ coordiantes from:
% https://www.biosemi.com/headcap.htm
this_elp = fullfile('doc', 'biosemi-64-xyz.txt'); % used to use: 'data/142130.elp'