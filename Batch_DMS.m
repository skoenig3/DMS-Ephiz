
clc
data_dir = 'C:\Users\seth.koenig\Documents\MATLAB\DMS Ephiz\Recording Files\'; %where to get data from
figure_dir = 'C:\Users\seth.koenig\Documents\MATLAB\DMS Ephiz\Figures\'; %where to save figures

dms_files = {'TO160309_2-sorted.nex'};
multiunits = {[0 0 0]};


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---Preprocess all the DMS data---%%%
% for f = 1:length(dms_files)
%     Import_DMS_RecordingData(data_dir,dms_files{f},multiunits{f})
% end

%%%---Automatically plot rasters---%%%
% for f = 1:length(dms_files)
%     make_rasters_DMS(data_dir,dms_files{f},figure_dir,multiunits)
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---Autmoatically analyze for event locked cells for DMS--%%%
for f = 1:length(dms_files)
    time_locked_DMS(data_dir,figure_dir,dms_files{f})
end


