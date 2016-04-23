function trl = trialfunDMS(cfg)
% written by Seth Konig on March 7, 2016

% Cuts out all of the trial data from one session.
% Structure of a trial in event codes:
% 150 TRIAL_START
% 100 start eye data
% 5000+x trial number
% 1000+x condition number
% 500+x block number

% 13 wait lever
% 7 Bar down or 208 if no bar down.
% 14 end wait lever
% 35 turn fixation cross on
% 11 wait fixation
% 8 fixation occurs or 204 if no fixation
% 207 encodes a response before test from now on
% 203 encodes a break fixation error
% 202 encodes an early response

% read the header
hdr = ft_read_header(cfg.dataset);
% read the events
event = ft_read_event(cfg.dataset);

% going to add codes to the end of trials since there is ~100 ms break in
% between for cortex
start_pause = 19;
end_pause = 20;

event = struct2cell(event);
event = cell2mat(event(1:2,:));
trial_start = 150;
trial_end = 151;
trial = {};
trial_count = 1;
starts = find(event(2,:) == trial_start);
ends = find(event(2,:) == trial_end);
if starts(1) > ends(1); %must have started recording after the task started
    ends(1) = [];
    starts(end) = [];
end
if length(starts)-length(ends) == 1;
    starts(end) = [];
elseif  length(starts)-length(ends) > 1
    disp('error something wrong with the encodes. More than 1 difference in when trial starts and trials end');
end
for t = 1:length(starts);
    trial{1,t} = event(2,starts(t):ends(t)); %event codes
    trial{2,t} = event(1,starts(t):ends(t)); %time of event
end

% careful when trying to find indeces and 5th event appears to have been
% codede wrong in some case it supposed to be 5000 + trial # by may just be
% trial # except for the 1st trial which may not have a pretrial in which
% the trial # is in the 3rd location
numrpt = size(trial,2);
valrptcnt = 0;
clear trl clrchgind
for rptlop = 1:numrpt
    if length(find(trial{1,rptlop} == 200)) ~=0 && length(find(trial{1,rptlop} == 151)) ~= 0 
        trlbegind = find(trial{1,rptlop} ==  150); % start at pretrial since I need this data for some things
        trlendind = find(trial{1,rptlop} == 151); % end at end trial
        if length( trlbegind) > 1
            trlbegind = trlbegind(2);
            trlendind = trlendind(2);
        end
        cndnumind = find(trial{1,rptlop} >= 1000 & trial{1,rptlop} <=2000);
        begtimdum = trial{2,rptlop}(trlbegind);
        endtimdum = trial{2,rptlop}(trlendind);
        if endtimdum > begtimdum
            valrptcnt = valrptcnt + 1;
            clrchgind(valrptcnt)=rptlop;
            trl(valrptcnt).begsmpind = begtimdum;
            trl(valrptcnt).endsmpind = endtimdum;
            trl(valrptcnt).cnd = trial{1,rptlop}(cndnumind);
            trl(valrptcnt).allval = trial{1,rptlop};
            trl(valrptcnt).alltim = trial{2,rptlop};
            trl(valrptcnt).event = rptlop;
        end
    end
end

for t = 1:length(trl)
    if t == length(trl)
        trl(t).endsmpind = trl(t).endsmpind+100;
        trl(t).allval = [trl(t).allval start_pause end_pause];
        trl(t).alltim = [trl(t).alltim trl(t).alltim(end)+1 trl(t).alltim(end)+100];
    else
        next_trialstart = trl(t+1).alltim(1);
        trl(t).endsmpind = next_trialstart-1;
        trl(t).allval = [trl(t).allval start_pause end_pause];
        trl(t).alltim = [trl(t).alltim trl(t).alltim(end)+1 next_trialstart-1];
    end
end
