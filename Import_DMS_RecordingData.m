function Import_DMS_RecordingData(data_dir,dms_file,multiunit)
% written March 7, 2016 by Seth Konig
%
% Function imports and preprocesses CVTNEW data from plexon recordings.
% NOTE Plexon eye tracking values (i.e. voltage values) are different from what cortex
% recieves though the they seem to map likely due to differences in cable
% length or other differences in inherent resistnaces throughout the
% system. Currently this function does not apply Cluster Fix to the XY data.
%
% Inputs:
%   1) data_dir: directory containing dms_file
%   2) dms_file: spike sorted nex recording file
%   3) multiunit: 1 for mulitunit 0 for single unit
% Outputs:
%   1) saves preprocessed data to data_dir

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---Import Plexon_nex File Data---%%%
%define the trials solely based on the marker events
cfg=[];
cfg.channel = {};
cfg.dataset       = [data_dir dms_file];
cfg.trialfun      = 'trialfunDMS';
cfg.datatype      = 'continuous';
cfg = ft_definetrial(cfg);

% read the data from file and preprocess them
% Want spike data (valid units only), LFPs, and X and Y eye data
fieldtripdefs
hdr = ft_read_header(cfg.headerfile, 'headerformat', cfg.headerformat);
num_units = 0;
waveform_channels = [];
for l = 1:length(hdr.label);
    if ~isempty(strfind(hdr.label{l},'sig'));
        if isempty(strfind(hdr.label{l},'wf')); %all recorded unit spike times
            if isempty(strfind(hdr.label{l}(7),'i'));%i is for invalidated waveforms rest are valid waveforms
                cfg.channel = [cfg.channel hdr.label(l)]; %all recorded "units"
                num_units = num_units+1;
            end
        else
            if isempty(strfind(hdr.label{l}(7),'i'));%i is for invalidated waveforms, rest are valid waveforms
                waveform_channels= [waveform_channels l];
            end
        end
    elseif ~isempty(strfind(hdr.label{l},'X')); %horiziontal eye data
        cfg.channel = [cfg.channel hdr.label(l)];
    elseif ~isempty(strfind(hdr.label{l},'Y')); %vertical eye data
        cfg.channel = [cfg.channel hdr.label(l)];
    elseif ~isempty(strfind(hdr.label{l},'AD'));  %LFP data by channel
        cfg.channel = [cfg.channel hdr.label(l)];
    end
end
[data,skipped_trials] = getPlexonTrialData(cfg);

for s = 1:length(skipped_trials);
    cfg.trl(skipped_trials(s)) = [];
end

% import waveforms seperately for some reason couldn't get it to work above
waveforms = cell(1,length(waveform_channels));
for wv = 1:length(waveform_channels);
    spikewaves = read_plexon_nex(cfg.dataset , 'channel',waveform_channels(wv));
    waveforms{wv} = spikewaves.dat;
end

disp('Data imported Successfully')


%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---Save the Data---%%%
save([data_dir dms_file(1:end-11) '-preprocessed.mat'],'cfg','data','hdr',...
    'num_units','waveforms','multiunit');
disp(['Data  from ' dms_file ' Successfully Preprocessed and Saved'])