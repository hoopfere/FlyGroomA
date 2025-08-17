case 'BORIS'
                    %% Convert BORIS to mat files

                    % Load the events from the file(s).
                    for fileIndex = 1:fileCount
                        events(fileIndex).file_path = app.filePaths{fileIndex};

                        % Read BORIS xlsx file & format
                        T = readtable(app.filePaths{fileIndex});
                        T.Behavior = categorical(T.Behavior);
                        T.BehaviorType = categorical(T.BehaviorType);


                        %lowerbehavs = string(T.Behavior); % convert behaviors to string so it can be searched in case insensitive manner
                        % convert param_behavs to standard format (no caps, no spaces)
                        % alert user of differences
                        behaviorNames = cellstr(T.Behavior);
                        for i = 1:length(behaviorNames)
                            new_name = behaviorToFieldName(app,behaviorNames{i});
                            if ~strcmp(behaviorNames{i},new_name)
                                behaviorNames{i} = new_name;
                            end
                        end

                        % replace Behaviors in Table with formatted names
                        T.Behavior = categorical(behaviorNames);

                        % Get the start time and duration of all events for each type of behavior.
                        uniqueBehaviors = unique(T.Behavior);

                        % remove any <undefined> entries
                        % TODO: check what this does
                        uniqueBehaviors = uniqueBehaviors(~isundefined(uniqueBehaviors));

                        % check to see if any of the uniqueBehaviors are
                        % not found in param_behavs and alert user.
                        notfound = ~ismember(uniqueBehaviors,param_behavs);
                        InvalidNames = cellstr(uniqueBehaviors(notfound));
                        if ~isempty(InvalidNames)
                            uialert(app.UIFigure, ['The following behavior names were not found in your parameters file. Make sure to check spelling and formatting.' InvalidNames'], 'Invalid Behavior Names!');
                        end

                        % for b = 1:length(uniqueBehaviors)
                        %     behavior = char(uniqueBehaviors(b));
                        for b = 1:length(param_behavs)
                            behavior = char(param_behavs(b));

                            % Get the indices of the events for this behavior.
                            behaviorIdxs = T.Behavior==behavior; %TODO categorical searches are case sensitive!!
                            %behaviorIdxs = strcmpi(lowerbehavs, behavior);

                            if sum(behaviorIdxs)==0 % no events found
                                % Store the start times and durations for the behavior.
                                events(fileIndex).(behaviorToFieldName(app,behavior)) = [];
                            else
                                % Get the start times and durations at those indices.
                                startTimes = str2double(T.Time(T.Behavior==behavior & T.BehaviorType=='START'));
                                stopTimes = str2double(T.Time(T.Behavior==behavior & T.BehaviorType=='STOP'));
                                
                                % check to see if there are the same number
                                % of starts and stops
                                nStarts=length(startTimes);
                                nStops = length(stopTimes);

                                if nStarts > nStops
                                   % start w/o stop (most likely)
                                   if nStarts-nStops > 1
                                       % display error to user saying there
                                       % are multiple unclose events
                                   else 
                                       stopTimes(end+1) = app.endTime;
                                   end
                                elseif nStarts < nStops
                                    % stop w/o start (unlikely)
                                    if nStops-nStarts > 1
                                        % display error to user saying
                                        % there are multiple unstarted
                                        % events
                                    else
                                        startTimes = [app.startTime ; starTimes];
                                    end
                              
                                end
                                
                                durations = stopTimes - startTimes;
                                
                                % Could there be start or stops without a partner?

                                % Restrict to the events within the time window.
                                % Eliminate events that completely
                                % outside window (startTime>app.endTime | stopTime<app.startTimes)
                                idx = ones(1,length(startTimes));
                                for i = 1:length(startTimes)
                                    if startTimes(i) > app.endTime || stopTimes(i) < app.startTime
                                        % if event starts after app.endTime or ends before app.startTime, eliminate
                                        idx(i) = 0;
                                    elseif startTimes(i) < app.startTime && stopTimes(i) > app.endTime
                                        % if event starts before app.startTime and ends after app.endTime (spans
                                        % entire window), trim to window
                                        startTimes(i) = app.startTime;
                                        stopTimes(i) = app.endTime;
                                        durations(i) = app.endTime - app.startTime;
                                    elseif startTimes(i) < app.startTime && stopTimes(i) < app.endTime
                                        % if event start before app.startTime but ends before app.endTime, start
                                        % at app.startTime
                                        startTimes(i) = app.startTime;
                                        durations(i) = stopTimes(i)-app.startTime;
                                    elseif startTimes(i) < app.endTime && stopTimes(i) > app.endTime
                                        % if event starts before app.endTime and ends after app.endTime, set
                                        % end to app.endTime
                                        stopTimes(i) = app.endTime;
                                        durations(i) = app.endTime - startTimes(i);
                                    end
                                end
                                idx = logical(idx);
                                startTimes = startTimes(idx);
                                %stopTimes = stopTimes(idx);
                                durations = durations(idx);
                                
                                % Store the start times and durations for the behavior.
                                %events(fileIndex).(behaviorToFieldName(app,behavior)) = horzcat(startTimes(idxs), durations(idxs)); %#ok<AGROW>
                                events(fileIndex).(behaviorToFieldName(app,behavior)) = horzcat(startTimes, durations); %#ok<AGROW>
                            end

                        end
                    end

                    % Duplicate events for classes
                    behaviorClassNames = fieldnames(app.behaviorClasses);
                    for c = 1:length(behaviorClassNames)
                        behaviorClass = behaviorClassNames{c};
                        behaviors = app.behaviorClasses.(behaviorClass).behaviors;
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