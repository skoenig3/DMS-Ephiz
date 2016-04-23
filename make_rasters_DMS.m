function make_rasters_DMS(data_dir,task_file,figure_dir,multiunit)
% written by Seth Konig August 2014. Updated January 2016 by SDK
% 1) Plots spike trains aligned to trial start. Below is the PSTH.
% 2) Plots waveform divided into 1/4 of the task at time
% 3) Plots firing rate over time/trials
% 4) defines which trials should be used for data analysis if firing rate
% is not stable

%aligns data to ITI start

reward_code = 3;
item_1_on_code = 23;
ITI_code = 150;
binsize = 35;%ms probably want 25-100 ms
trialbinsize = 6;%averging data by trial number

%get important task related data
load([data_dir task_file(1:end-11) '-preprocessed.mat'],'cfg','data','hdr','multiunit');

num_units = length(find_desired_channels(cfg,'unit'));

valid_trials = NaN(2,num_units);%trials we want to keep based on firing rate
for unit = 1:num_units
    allspikes = NaN(length(cfg.trl),7000);
    allspikesITI = NaN(length(cfg.trl),2000);
    for t = 1:length(cfg.trl);
        trial_start = cfg.trl(t).alltim(cfg.trl(t).allval == ITI_code);
        event_ind = find(cfg.trl(t).allval == item_1_on_code);
        event_ind = event_ind(1);
        event = cfg.trl(t).alltim(event_ind)-trial_start;
        
        spikes =data(unit).values{t};
        %locked to the ITI
        allspikesITI(t,:) = spikes(1:2000);
        
        %locked to main event
        spikes = find(spikes);
        spikes = spikes-event;
        spikes(spikes < 1) = [];
        spikes(spikes > 7000) = [];
        allspikes(t,spikes) = 1;
    end
    
    
    %determine spike per groups of trials to determine if firing rate is approximately stable over time
    spikespertrial = bin1(allspikes',trialbinsize)'./trialbinsize;
    ITIspikespertrial = bin1(allspikesITI',trialbinsize)'./trialbinsize;
    allspikespertrial = spikespertrial+ITIspikespertrial; %not mutually exclusive but doens't matter for this
    
   if multiunit(unit)
        title_str = ['Multiunit ' cfg.channel{unit}];
    else
        title_str = cfg.channel{unit};
    end
    
    cvtnewplot(allspikes,allspikesITI,allspikespertrial,spikespertrial,...
        ITIspikespertrial,trialbinsize,binsize)
    subtitle(title_str);
    
    
    %determine trial cutoffs based on firing rate over the session
    median_numspikes =  median(allspikespertrial); %hsould work better than mean for low firing rate neurons
    std_numspikes =  std(allspikespertrial);
    lower_bound = median_numspikes-1.5*std_numspikes;
    upper_bound = median_numspikes+1.5*std_numspikes;
    
    cutoffu = find(allspikespertrial > upper_bound);
    cutoffl = find(allspikespertrial < lower_bound);
    
    if isempty(cutoffu) && isempty(cutoffl)
        reply = input(['You can keep these trials. Is this Ok? [Y/#s]: /n' ...
            'If NO please state [trial start and trial end].']);
        if isnumeric(reply)
            [start_end] = listsqTrialCutoffplots(reply,allspikes,type,allspikesITI,allspikespertrial,...
                spikespertrial,ITIspikespertrial,trialbinsize,binsize);
        end
        valid_trials(:,unit) = start_end';
    else %else move on  to the next unit
        reply = [max(max(cutoffu),max(cutoffl)),min(min(cutoffl),min(cutoffu))];
        if isempty(reply)
            reply = [NaN NaN];
        end
        [start_end] = cvtnewTrialCutoffplots(reply,allspikes,allspikesITI,allspikespertrial,...
            spikespertrial,ITIspikespertrial,trialbinsize,binsize);
    end
    valid_trials(:,unit) = start_end';
    
    subtitle(title_str);
    save_and_close_fig(figure_dir,[task_file(1:end-11) '_' title_str '_raster']);
end

%add the valid trials variable to preprocess file
save([data_dir task_file(1:end-11) '-preprocessed.mat'],'-append','valid_trials')
end

function cvtnewplot(allspikes,allspikesITI,allspikespertrial,...
    spikespertrial,ITIspikespertrial,trialbinsize,binsize)
%plot the cvtnew

if ~isempty(findall(0,'Type','Figure'))
    g = gcf;
    if g.Number == 101;
        close
    end
end


figure(101);

screen_size = get(0, 'ScreenSize');
set(gcf, 'Position', [0 0 screen_size(3) screen_size(4)]);
pause(0.5) %give time for plot to reach final size

% Rasters from Main Event
subplot(3,2,1)
[trial,time] = find(allspikesITI == 1);
plot(time,trial,'.k')
ylim([0 max(trial)])
ylabel('Trial #')
xlim([0 2000])

subplot(3,2,2)
[trial,time] = find(allspikes == 1);
plot(time,trial,'.k')
ylim([0 max(trial)])
ylabel('Trial #')
xlim([0 7000])


%PSTHs from main event
subplot(3,2,3)
asp = bin1(allspikesITI,binsize,'lower','sum');
bar(binsize:binsize:binsize*length(asp),asp,'k');
box off
xlim([0 2000])
ylabel('Count')
xlabel('Time from ITI Start (ms)')
title('PSTH')

subplot(3,2,4)
asp = bin1(allspikes,binsize,'lower','sum');
bar(binsize:binsize:binsize*length(asp),asp,'k');
box off
xlim([0 7000])
ylabel('Count')
xlabel('Time from Item 1 On (ms)')
title('PSTH')

subplot(3,2,5:6)
hold on
b = bar(spikespertrial);
set(b,'edgecolor','blue')
b = bar(ITIspikespertrial,'green');
set(b,'edgecolor','none','FaceAlpha',0.5)
xl = xlim;
plot([xl(1) xl(2)],[median(allspikespertrial) median(allspikespertrial)],'k-','linewidth',5)
plot([xl(1) xl(2)],[median(allspikespertrial)-std(allspikespertrial) median(allspikespertrial)-std(allspikespertrial)],'k--')
plot([xl(1) xl(2)],[median(allspikespertrial)+std(allspikespertrial) median(allspikespertrial)+std(allspikespertrial)],'k--')
hold off
xlabel(['Groups of Trials (' num2str(trialbinsize) 'trials/group)'])
ylabel('Average Spikes per trial')

end

function [start_end] = listsqTrialCutoffplots(reply,allspikes,type,allspikesITI,allspikespertrial,...
    spikespertrial,ITIspikespertrial,trialbinsize,binsize)
%plot the cutoffs from replys
while isnumeric(reply)
    listsqplot(allspikes,type,allspikesITI,allspikespertrial,spikespertrial,...
        ITIspikespertrial,trialbinsize,binsize)
    
    start_end = reply;
    
    %for plotting and visualization should put a line down
    nano = 0;
    if isnan(reply(1));
        reply(1) = 0;
    elseif isnan(reply(2))
        nano = 1;
    end
    for sb = [1:3 7 8];
        if sb == 8
            subplot(3,3,8:9)
            yl = ylim;
            hold on
            plot([reply(1)/trialbinsize reply(1)/trialbinsize],[0 yl(2)],'r');
            plot([reply(2)/trialbinsize reply(2)/trialbinsize],[0 yl(2)],'r');
            hold off
        else
            subplot(3,3,sb)
            xl = xlim;
            if nano
                yl = ylim;
                hold on
                plot([0 xl(2)],[reply(1) reply(1)],'r');
                plot([0 xl(2)],[yl(2) yl(2)],'r');
                hold off
            else
                hold on
                plot([0 xl(2)],[reply(1) reply(1)],'r');
                plot([0 xl(2)],[reply(2) reply(2)],'r');
                hold off
            end
        end
    end
    
    reply = input(['You can keep these trials. Is this Ok? [Y/#s]: \n' ...
        'If NO please state [trial start and trial end].']);
    
end
end

function [start_end] = cvtnewTrialCutoffplots(reply,allspikes,allspikesITI,allspikespertrial,...
    spikespertrial,ITIspikespertrial,trialbinsize,binsize)
%plot the cutoffs from replys
while isnumeric(reply)
    cvtnewplot(allspikes,allspikesITI,allspikespertrial,spikespertrial,...
        ITIspikespertrial,trialbinsize,binsize)
    
    start_end = reply;
    
    %for plotting and visualization should put a line down
    nano = 0;
    if isnan(reply(1));
        reply(1) = 0;
    elseif isnan(reply(2))
        nano = 1;
    end
    
    subplot(3,2,5:6)
    yl = ylim;
    hold on
    plot([reply(1)/trialbinsize reply(1)/trialbinsize],[0 yl(2)],'r');
    plot([reply(2)/trialbinsize reply(2)/trialbinsize],[0 yl(2)],'r');
    hold off
    
    subplot(3,2,1)
    xl = xlim;
    if nano
        yl = ylim;
        hold on
        plot([0 xl(2)],[reply(1) reply(1)],'r');
        plot([0 xl(2)],[yl(2) yl(2)],'r');
        hold off
    else
        hold on
        plot([0 xl(2)],[reply(1) reply(1)],'r');
        plot([0 xl(2)],[reply(2) reply(2)],'r');
        hold off
    end
    
    subplot(3,2,2)
    xl = xlim;
    if nano
        yl = ylim;
        hold on
        plot([0 xl(2)],[reply(1) reply(1)],'r');
        plot([0 xl(2)],[yl(2) yl(2)],'r');
        hold off
    else
        hold on
        plot([0 xl(2)],[reply(1) reply(1)],'r');
        plot([0 xl(2)],[reply(2) reply(2)],'r');
        hold off
    end
    
    
    reply = input(['You can keep all trials. Is this Ok? [Y/#s]: \n' ...
        'If NO please state [trial start and trial end].']);
    
end
end

