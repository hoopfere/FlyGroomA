function compileGroomingData_allcomp()
%COMPILEGROOMINGDATA formats data from manually-scored (VCode or Noldus) grooming experiments
%into matlab readable structures for processing by
%GROOMING_ANALYSIS
%
%INPUT
%   EVTS.TXT files that user chooses. Should be a group of experiments to
%   be grouped together for analysis (i.e., genotype)
%
%   filetype = 'VCode' or 'Noldus'
%
%   PARAMS CSV FILE (to be added)
%
%OUTPUT
%   EVENTS - structure 1xnumber of evts.txt files.
%       Fields include:
%       file_path (path to evts.txt)
%       behaviors (start time & duration in seconds)
%
%   STATS - 1x1 structure with descriptive statistics for all experiments
%
%   GENOTYPE - user-specified genotype (inherit form GUI in future)
%
%   TIMERANGE - user-specified timerange of analysis (inherit form GUI in
%   future)

%% Prompt the user for the file(s) to use.
[fileNames, dirName, filterIndex] = uigetfile({'*.txt','Text files (*.txt)'}, 'Pick the files for this line', 'MultiSelect', 'on');
if isscalar(fileNames)
    return % the user cancelled
end
if iscell(fileNames)
    filePaths = {};
    for fileName = fileNames
        filePaths = [filePaths fullfile(dirName, char(fileName))]; %#ok<AGROW>
    end
    filePaths = sort(filePaths);
else
    filePaths = {fullfile(dirName, fileNames)};
end
fileCount = length(filePaths);

% Determine the genotype of the files. Only works with GMR notation.
genotype = '';
[path, fileName, ext] = fileparts(filePaths{1});
parts = regexp(fileName, '_', 'split');
gmrPart = find(cellfun('size', strfind(parts, 'GMR'), 1));
if ~isempty(gmrPart)
    genotype = parts{gmrPart};
else
    gmrPart = regexp(parts, '^[0-9]{1,3}[A-Z][0-9][0-9]$');
    gmrPart = find(~cellfun(@isempty, gmrPart), 1);
    if ~isempty(gmrPart)
        genotype = parts{gmrPart};
    else
        gal4Part = find(cellfun('size', strfind(parts, 'GAL4'), 1));
        if ~isempty(gal4Part)
            genotype = parts{gal4Part};
        end
    end
end
genotype = inputdlg(['Enter the genotype for ' fileName ':'], 'Genotype', 2, {genotype});
if isempty(genotype)
    return
end
genotype = genotype{1};

%% Ask the user for the time range
prompt = {'Enter start time:','Enter end time:'};
answer = inputdlg(prompt, 'Time range for analysis (seconds)', 1, {'0', '120'});
if isscalar(answer)
    return % the user cancelled
end
timeRange = [sscanf(answer{1}, '%f') sscanf(answer{2}, '%f')];

%% Ask user to specify file type

filetype = questdlg('Select file type:', ...
    'File Type Selection', ...
    'Noldus', 'VCode', 'Noldus');


%% Ask user to select behavior_params.csv file to define classes

[bfileName,bdirName] = uigetfile({'*.csv','csv files (*.csv)'}, 'Select behavior param csv file');
[behaviorClasses, ~, ~] = import_behavparams(bdirName,bfileName);

%     % Behavior Classes (this will be imported from a params file in future)
%     behaviorClasses.head_cleaning = {'head_cleaning', 'antennal_cleaning', 'proboscis_cleaning', 'ventral_head'};
%     behaviorClasses.front_leg_rubbing = {'front_leg_rubbing', 'b_1st_and_2nd_leg_rub', 'front_proximal_leg_rub'};
%     behaviorClasses.wing_cleaning = {'wing_cleaning', 'ventral_wing', 'wing_blade', 'wing_hinge_slash_haltere'};
%     behaviorClasses.back_leg_rubbing = {'back_leg_rubbing', 'proximal_leg_rub', 'b_2nd_and_3rd_leg_rub'};
%     behaviorClasses.abdominal_cleaning = {'abdominal_cleaning', 'genital_cleaning'};
%     behaviorClasses.other = {'ventral_front_cleaning', 'grooming_attempt', 'first_leg_notum', 'ventral_back_cleaning', ...
%                              'back_leg_grooming_attempt', 'standing_still', 'on_back', 'slip_slash_jump', 'ventral_middle'};

%% Convert Noldus to mat files

% Load the events from the file(s).
for fileIndex = 1:fileCount
    events(fileIndex).file_path = filePaths{fileIndex};

    % Read Noldus text file & format
    T = readtable(events(fileIndex).file_path,'Delimiter',';');
    T.Behavior = categorical(T.Behavior);
    T.Event_Type = categorical(T.Event_Type);


    % Get the start time and duration of all events for each type of behavior.
    uniqueBehaviors = unique(T.Behavior);

    % remove any <undefined> entries
    uniqueBehaviors = uniqueBehaviors(~isundefined(uniqueBehaviors));
    
    for b = 1:length(uniqueBehaviors)
        behavior = char(uniqueBehaviors(b));

        % Get the indices of the events for this behavior.
        behaviorIdxs = T.Behavior==behavior;


        % Get the start times and durations at those indices.
        startTimes = T.Time_Relative_sf(T.Behavior==behavior & T.Event_Type=='State start');
        stopTimes = T.Time_Relative_sf(T.Behavior==behavior & T.Event_Type=='State stop');
        %durations = stopTimes - startTimes;
        durations = T.Duration_sf(T.Behavior==behavior & T.Event_Type=='State start');

        % Restrict to the events within the time window.
        idxs = (startTimes < app.endTime & stopTimes > app.startTime);

        % Store the start times and durations for the behavior.
        events(fileIndex).(behaviorToFieldName(behavior)) = horzcat(startTimes(idxs), durations(idxs)); %#ok<AGROW>
    end
end

% Duplicate events for classes
behaviorClassNames = fieldnames(behaviorClasses);
for c = 1:length(behaviorClassNames)
    behaviorClass = behaviorClassNames{c};
    behaviors = behaviorClasses.(behaviorClass).behaviors;
    %behaviorClass = ['class_' behaviorClass]; %#ok<AGROW>
    for f = 1:length(events)
        events(f).(behaviorClass) = []; %#ok<AGROW>

        for b = 1:length(behaviors)
            behavior = behaviors{b};
            if isfield(events(f), behavior)
                behaviorEvents = events(f).(behavior);

                if ~isempty(behaviorEvents)
                    events(f).(behaviorClass) = vertcat(events(f).(behaviorClass), behaviorEvents); %#ok<AGROW>
                end
            end
        end

        events(f).(behaviorClass) = sortrows(events(f).(behaviorClass)); %#ok<AGROW>
    end
end


% Calculate the statistics for each behavior and class.
stats = struct;
behaviors = fieldnames(events);
for i = 1:length(behaviors)
    behavior = behaviors{i};
    if ~strcmp(behavior, 'file_path')
        stats.(behavior) = eventsStats(events, behavior, timeRange);
    end
end

timeRange(2) = timeRange(2) - timeRange(1); %#ok<NASGU>

% TODO: sanitize genotype for file name usage?
savePath = fullfile(dirName, [genotype '.mat']);
save(savePath, 'genotype', 'timeRange', 'events', 'stats');

%% VCode conversion
% Load the events from the file(s).
for fileIndex = 1:fileCount
    events(fileIndex).file_path = filePaths{fileIndex}; %#ok<AGROW>

    % Open and determine the type of file.
    fid = fopen(events(fileIndex).file_path);
    firstLine = fgets(fid);
    frewind(fid);

    try
        if strncmp(firstLine, '"Start Date:"', 12)
            % Read the timestamp, behavior name and event type columns from a Noldus Observer file.
            rawEvents = textscan(fid, '"%f" %*q %*q %*q %q %q %*q', -1, 'HeaderLines', 5, 'delimiter', ',');

            % Get the start time and duration of all events for each type of behavior.
            uniqueBehaviors = setdiff(rawEvents{2}, {''});
            for b = uniqueBehaviors'
                behavior = char(b);

                % Get the indices of the events for this behavior.
                behaviorIdxs = find(strcmp(rawEvents{2}, behavior));
                behaviorTimes = rawEvents{1}(behaviorIdxs);

                % Get the start times and durations at those indices.
                startIdxs = strcmp(rawEvents{3}(behaviorIdxs), 'State start');
                startTimes = behaviorTimes(startIdxs);
                stopIdxs = strcmp(rawEvents{3}(behaviorIdxs), 'State stop');
                stopTimes = behaviorTimes(stopIdxs);
                durations = stopTimes - startTimes;

                % Restrict to the events within the time window.
                idxs = (startTimes < timeRange(2) & stopTimes > timeRange(1));

                % Store the start times and durations for the behavior.
                events(fileIndex).(behaviorToFieldName(behavior)) = horzcat(startTimes(idxs), durations(idxs)); %#ok<AGROW>
            end
        elseif strncmp(firstLine, 'Offset:', 7)
            % Read the start time (ms), duration (ms) and behavior name columns from a VCode file that looks like:
            %   Offset: 0, Movie: MoviePathHere, DataFile: (null)
            %   Tracks: Grooming, Feeding
            %   Time,Duration,TrackName,comment
            %
            %   1260,824,Feeding,(null)
            %   2349,408,Grooming,(null)
            %   ...
            % rawEvents = [{start times} {durations} {Behavior}
            % {comment}]
            rawEvents = textscan(fid, '%f %f %s %s', -1, 'HeaderLines', 4, 'delimiter', ',');

            uniqueBehaviors = setdiff(rawEvents{3}, {''}); %Behaviors found in file

            for b = uniqueBehaviors'
                behavior = char(b);

                % Get the indices of the events for this behavior.
                behaviorIdxs = find(strcmp(rawEvents{3}, behavior));
                startTimes = rawEvents{1}(behaviorIdxs) / 1000;
                durations = rawEvents{2}(behaviorIdxs) / 1000;

                % Store the start times and durations for the behavior.
                events(fileIndex).(behaviorToFieldName(behavior)) = horzcat(startTimes, durations); %#ok<AGROW>
            end
        end
    catch ME
        fclose(fid);
        rethrow(ME);
    end
    fclose(fid);
end

% Duplicate events for classes
behaviorClassNames = fieldnames(behaviorClasses);
for c = 1:length(behaviorClassNames)
    behaviorClass = behaviorClassNames{c};
    behaviors = behaviorClasses.(behaviorClass).behaviors;
    %behaviorClass = ['class_' behaviorClass]; %#ok<AGROW>
    for f = 1:length(events)
        events(f).(behaviorClass) = []; %#ok<AGROW>

        for b = 1:length(behaviors)
            behavior = behaviors{b};
            if isfield(events(f), behavior)
                behaviorEvents = events(f).(behavior);

                if ~isempty(behaviorEvents)
                    events(f).(behaviorClass) = vertcat(events(f).(behaviorClass), behaviorEvents); %#ok<AGROW>
                end
            end
        end

        events(f).(behaviorClass) = sortrows(events(f).(behaviorClass)); %#ok<AGROW>
    end
end


% Calculate the statistics for each behavior and class.
stats = struct;
behaviors = fieldnames(events);
for i = 1:length(behaviors)
    behavior = behaviors{i};
    if ~strcmp(behavior, 'file_path')
        stats.(behavior) = eventsStats(events, behavior, timeRange);
    end
end

timeRange(2) = timeRange(2) - timeRange(1); %#ok<NASGU>

% TODO: sanitize genotype for file name usage?
savePath = fullfile(dirName, [genotype '.mat']);
save(savePath, 'genotype', 'timeRange', 'events', 'stats');
end


function s = eventsStats(events, behavior, timeRange)
% Compute the statistics for the events of the indicated behavior.

totalDuration = timeRange(2) - timeRange(1);

% Compute the bout frequencies and total times for each fly.
for f = 1:length(events)
    % create bout_freq & total_time fields
    s.bout_freq(f) = 0;
    s.total_time(f) = 0;

    % determine if fly did this behavior. If not, set as empty matrix
    if isfield(events(f), behavior)
        behaviorEvents = events(f).(behavior);
    else
        behaviorEvents = [];
    end

    % Don't include bouts that are outside of the start or end time points.
    if ~isempty(behaviorEvents) && behaviorEvents(1, 1) < timeRange(1)
        behaviorEvents = behaviorEvents(2:end, :);
    end
    if ~isempty(behaviorEvents) && behaviorEvents(end, 1) + behaviorEvents(end, 2) > timeRange(2)
        behaviorEvents = behaviorEvents(1:(end-1), :);
    end

    % If there are still events, extract the bout frequency & total
    % time
    if ~isempty(behaviorEvents)
        %             s.bout_freq(f) = 0;     % Note: this is redundant since already set above
        %             s.total_time(f) = 0;
        %         else
        s.bout_freq(f) = size(behaviorEvents, 1);                       % number of events across flies
        s.total_time(f) = sum(behaviorEvents(:, 2));                    % total time in sec behavior performed
    end
end

% Compute all of the derived stats.
s.bout_freq_mean = mean(s.bout_freq);                                   % average number of events per expt
s.bout_freq_median = median(s.bout_freq);                               % median number of events per expt
s.bout_freq_std = std(s.bout_freq);                                     % standard deviation of num events/expt
s.bout_freq_stderr = s.bout_freq_std ./ sqrt(length(s.bout_freq));      % standard error of num events/expt

s.bout_rate = s.bout_freq / totalDuration * 60;                         % events per minute
s.bout_rate_mean = mean(s.bout_rate);
s.bout_rate_median = median(s.bout_rate);
s.bout_rate_std = std(s.bout_rate);
s.bout_rate_stderr = s.bout_rate_std ./ sqrt(length(s.bout_rate));

s.bout_dur = s.total_time ./ s.bout_freq;                               % average duration of a bout
s.bout_dur(isnan(s.bout_dur)) = 0;
s.bout_dur_mean = mean(s.bout_dur);
s.bout_dur_median = median(s.bout_dur);
s.bout_dur_std = std(s.bout_dur);
s.bout_dur_stderr = s.bout_dur_std ./ sqrt(length(s.bout_dur));

s.total_time_mean = mean(s.total_time);                                 % total time performing behavior/expt
s.total_time_meadian = median(s.total_time);
s.total_time_std = std(s.total_time);
s.total_time_stderr = s.total_time_std ./ sqrt(length(s.total_time));

s.percent_time = s.total_time / totalDuration;                          % percent of time in expt performing behavior
s.percent_time_mean = mean(s.percent_time);
s.percent_time_median = median(s.percent_time);
s.percent_time_std = std(s.percent_time);
s.percent_time_stderr = s.percent_time_std ./ sqrt(length(s.percent_time));
end

