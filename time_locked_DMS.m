function time_locked_DMS(data_dir,figure_dir,task_file)
% written by Seth Konig August, 2014
% updated SDK 1/11/17 to handlde new format and partial session data for
% vaild trials only. Updated CVTNEW section on 1/19/16
% Function analyses spike times locked to events that occur on the monitor
% at the time dicated by cortex event codes. Analysis does not analyze eye
% movements directly but when cortex says the eye had entered the fixation
% window. Updates to come on this.
%
% Inputs:
%   1) data_dir: direction where preprocessed data is located
%   2) figure_dir: location of where to put save figures
%   3) session_data: data containing relevant session data
%   4) task: what task was this data come from with i.e. 'cvtnew','ListSQ'
%
% Outputs:
%   1) Saves figures to figure_dir
%   2) Saves processed data to data_dir tagged with '-time_locked_results'

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---Setup the events of interest---%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
reward_code = 3;
item_1_on_code = 23;
ITI_code = 150;
non_match_code = 300;

all_item_codes = [23 25 27 29 31 33];
all_item_durs = 1000;
all_item_tminus = 500;

event_names = {'ITI','Item 1 On','Reward'}; %the name of the event
event_codes = [ITI_code item_1_on_code reward_code]; %cortex code
event_dur = [1000 7000 1000]; %how long the event last e.g. ITI is 1 second while item 1 just turns on
event_tminus  = [0 500 500]; %how long before the event started do you want to look.
%you can look back in time on the ITI period but it's a little harder


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---import task and unit data---%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

load([data_dir task_file(1:end-11) '-preprocessed.mat'],'cfg','data','hdr','multiunit','valid_trials');
num_units = length(multiunit);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%---import & reformat data so that spikes are locked to events---%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

num_trials = length(cfg.trl);

%NaNs are for start and end trials otherwise cut
valid_trials(1,isnan(valid_trials(1,:))) = 1;
valid_trials(2,isnan(valid_trials(2,:))) = num_trials;

disp('Aligning spike times to trial events')

%%%preallocate space and parallel structure of cfg%%%

%for gross events e.g. trial start, ITI, and reward
time_lock_firing = cell(length(event_codes),num_units);
for unit = 1:num_units
    for event = 1:length(event_codes)
        time_lock_firing{event,unit} = NaN(length(cfg.trl),event_dur(event)+event_tminus(event));
    end
end

%for responses locked to items and matches vs non matches
time_lock_all_items = cell(8,2,num_units); %row by item # displayed, col by non-match or match, zcol by unit
for unit = 1:num_units
    for event = 1:8
        for nmm = 1:2
            time_lock_all_items{event,nmm,unit} = NaN(length(cfg.trl),all_item_durs+all_item_tminus);
        end
    end
end

for t = 1:num_trials
    for unit = 1:num_units
        if any(cfg.trl(t).allval == reward_code); %rewarded trials only
            trial_start = cfg.trl(t).alltim(cfg.trl(t).allval == ITI_code);
            if t >= valid_trials(1,unit) && t <= valid_trials(2,unit) %only put data in for valid trials
                for event = 1:length(event_codes)
                    spikes = data(unit).values{t}; %spike times
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %for gross events
                    temp = NaN(1,event_dur(event)+event_tminus(event)); %temporary variable in case event durations are variable
                    %grab the event times
                    event_time_start = cfg.trl(t).alltim(cfg.trl(t).allval == event_codes(event))-trial_start-event_tminus(event);
                    event_time_start(event_time_start == 0) = 1;%only should happen for ITI
                    event_time_start = event_time_start(1); %in case of multiple cortex codes per event (e.g. 5 rewards)
                    event_time_end = event_time_start + event_dur(event)+event_tminus(event)-1;
                    if event_time_end > length(spikes)
                        temp(1:length(spikes(event_time_start:end))) = spikes(event_time_start:end);
                    else
                        temp = spikes(event_time_start:event_time_end);
                    end
                    time_lock_firing{event,unit}(t,:) = temp; %store spikes in matrix
                    
                    
                    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
                    %%for responses locked to items and matches vs non matches
                    all_events = [];
                    for e = 1:length(all_item_codes);
                        event_time_start = cfg.trl(t).alltim(cfg.trl(t).allval == all_item_codes(e))-trial_start-all_item_tminus;
                        aec = all_item_codes(e)*ones(1,length(event_time_start));
                        all_events =[all_events [event_time_start; aec]];
                    end
                    [~,order] = sort(all_events(1,:));
                    all_events = all_events(:,order);
                    
                    for e = 1:length(all_events);
                        if e == 1 %sample
                            time_lock_all_items{e,1,unit}(t,:) = spikes(all_events(1,e):all_events(1,e)+...
                                all_item_durs+all_item_tminus-1);
                        elseif e == length(all_events) %match
                            time_lock_all_items{e,1,unit}(t,:) = spikes(all_events(1,e):all_events(1,e)+...
                                all_item_durs+all_item_tminus-1);
                        else %nonmatch
                            time_lock_all_items{e,2,unit}(t,:) = spikes(all_events(1,e):all_events(1,e)+...
                                all_item_durs+all_item_tminus-1);
                        end
                    end
                end
            end
        end
    end
end

%remove excess NaNs associated with error trials/excess time
time_lock_firing = laundry(time_lock_firing);
for unit = 1:3
    time_lock_all_items(:,:,unit) = laundry(time_lock_all_items(:,:,unit));
end

%%%%%%%%%%%%%%%%%%%%%
%%%---Plot Data---%%%
%%%%%%%%%%%%%%%%%%%%%
smval = 60; %temporal 1/2 width of gaussian smoothing filter for Nathan's DoFill fcn

%plots for gross events
for unit = 1:num_units
    ylimits = NaN(2,3);
    
    timestep = 250;
    
    figure
    subplot(2,2,1)
    t = 1:1000;
    dofill(t,time_lock_firing{1,unit},'black',1,smval);
    yl = ylim;
    ylimits(1,1) = yl(1);
    ylimits(2,1) = yl(2);
    set(gca,'Xtick',0:timestep:size(time_lock_firing{1,unit},2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_firing{1,unit},2))));
    xlabel('Time from ITI start (ms)')
    ylabel('Firing Rate (Hz)')
    
    subplot(2,2,2)
    t = -500:999;
    dofill(t,time_lock_firing{3,unit},'black',1,smval);
    set(gca,'Xtick',(0:timestep:size(time_lock_firing{3,unit},2))-event_tminus(2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_firing{3,unit},2))-event_tminus(2)));
    yl = ylim;
    ylimits(1,2) = yl(1);
    ylimits(2,2) = yl(2);
    xlabel('Time from Reward start (ms)')
    ylabel('Firing Rate (Hz)')
    
    timestep = 500;
    subplot(2,2,[3 4])
    t = -500:6999;
    dofill(t,time_lock_firing{2,unit},'black',1,smval);
    set(gca,'Xtick',0:timestep:size(time_lock_firing{2,unit},2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_firing{2,unit},2))-event_tminus(3)));
    yl = ylim;
    ylimits(1,3) = yl(1);
    ylimits(2,3) = yl(2);
    xlabel('Time from Item 1 On (ms)')
    ylabel('Firing Rate (Hz)')
    xlim([-500 7000])
    
    ymin = min(ylimits(1,:));
    ymin(ymin < 0) = 0;
    ymax = max(ylimits(2,:));
    for sb = 1:2
        subplot(2,2,sb)
        ylim([ymin ymax]);
    end
    subplot(2,2,[3 4])
    ylim([ymin ymax]);
    
    save_and_close_fig(figure_dir,[task_file(1:end-11) '_' cfg.channel{unit} '-time_locked_major_events'])
end


%plots for time locked to events
timestep = 250;
t = -500:999;
clror = jet(9);
for unit = 1:num_units
    ylimit = NaN(2,3);
    
    all_match = [];
    all_non_match = [];
    for e = 2:size(time_lock_all_items,1);
        all_match = [all_match; time_lock_all_items{e,1,unit}];
        all_non_match = [all_non_match; time_lock_all_items{e,2,unit}];
    end
    
    figure
    
    %plot match vs nonmatch
    subplot(1,3,1)
    hold on
    dofill(t,time_lock_all_items{1,1,unit},'black',1,smval); %sample
    dofill(t,all_match,'green',1,smval); %all matches
    dofill(t,all_non_match,'red',1,smval); %all non matches
    hold off
    yl = ylim;
    ylimits(1,2) = yl(1);
    ylimits(2,2) = yl(2);
    xlabel('Time Item On (ms)')
    set(gca,'Xtick',0:timestep:size(time_lock_all_items{1},2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_all_items{1},2))-all_item_tminus));
    legend('Sample','All NonMatch','All Match')
    ylabel('Firing Rate (Hz)')
    title('Sample vs Match vs NonMatach')
    
    %plot by non match number
    subplot(1,3,2)
    hold on
    dofill(t,time_lock_all_items{1,1,unit},'black',1,smval); %sample for references
       item_nums = [];
    for e = 2:7
        if size(time_lock_all_items{e,1,unit},1) > 10
            dofill(t,time_lock_all_items{e,2,unit},clror(e,:),1,smval); %all matches
            item_nums = [item_nums e-1];
        end
    end
    hold off
    yl = ylim;
    ylimits(1,2) = yl(1);
    ylimits(2,2) = yl(2);
    xlabel('Time Item On (ms)')
    set(gca,'Xtick',0:timestep:size(time_lock_all_items{1},2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_all_items{1},2))-all_item_tminus));
    legend([{'Sample'},num2cell(num2str([item_nums]'))'])
    ylabel('Firing Rate (Hz)')
    title('Effect of Order on NonMatch')
    
    %plot by  match number
    subplot(1,3,3)
    hold on
    dofill(t,time_lock_all_items{1,1,unit},'black',1,smval); %sample for references
    item_nums = [];
    for e = 2:7
        if size(time_lock_all_items{e,1,unit},1) > 10
            dofill(t,time_lock_all_items{e,1,unit},clror(e,:),1,smval); %all matches
            item_nums = [item_nums e-1];
        end
    end
    hold off
    yl = ylim;
    ylimits(1,2) = yl(1);
    ylimits(2,2) = yl(2);
    xlabel('Time Item On (ms)')
    set(gca,'Xtick',0:timestep:size(time_lock_all_items{1},2))
    set(gca,'XtickLabel',num2cell((0:timestep:size(time_lock_all_items{1},2))-all_item_tminus));
    legend([{'Sample'},num2cell(num2str([item_nums]'))'])
    ylabel('Firing Rate (Hz)')
    title('Effect of Order on NonMatch')
    
    ymin = min(ylimits(1,:));
    ymin(ymin < 0) = 0;
    ymax = max(ylimits(2,:));
    for sb = 1:3
        subplot(1,3,sb)
        ylim([ymin ymax]);
    end
    
    save_and_close_fig(figure_dir,[task_file(1:end-11) '_' cfg.channel{unit} '-time_locked_Items'])
end

save([data_dir task_file(1:end-11) '-time_locked_results.mat'],...
    'time_lock_firing','time_lock_all_items')
disp('Done. Date Saved too !!!')