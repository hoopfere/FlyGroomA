function [behaviorClasses, behavTable, behavList] = import_behavparams(dirName,fileName)
%IMPORT_BEHAVPARAMS This function imports behaviors and colors for grooming
%plots
%   Detailed explanation goes here
% dirName = filepath where csv param file is located
% fileName = name of csv params file to import


%% Import csv file and make struct

T = readtable(fullfile(dirName,fileName));

T.BehaviorClass = categorical(T.BehaviorClass);

% get BehaviorClasses and create structure
behav_classes = cellstr(unique(T.BehaviorClass));    % behavior classes from 1st col

% reorder behav_classes as specified in ClassOrder
T = sortrows(T,{'ClassOrder','BehaviorOrder'},{'ascend','ascend'}); % sort rows by class and behavior

order_ind = [];
for i = 1:length(behav_classes)
    order_ind = [order_ind unique(T{T.BehaviorClass==behav_classes{i},'ClassOrder'})];
end
[order_ind,idx] = sort(order_ind);
behav_classes = behav_classes(idx);


% % Behavior Classes (this will be imported from a params file in future)
%     behaviorClasses.head_cleaning = {'head_cleaning', 'antennal_cleaning', 'proboscis_cleaning', 'ventral_head'};
%     behaviorClasses.front_leg_rubbing = {'front_leg_rubbing', 'b_1st_and_2nd_leg_rub', 'front_proximal_leg_rub'};
%     behaviorClasses.wing_cleaning = {'wing_cleaning', 'ventral_wing', 'wing_blade', 'wing_hinge_slash_haltere'};
%     behaviorClasses.back_leg_rubbing = {'back_leg_rubbing', 'proximal_leg_rub', 'b_2nd_and_3rd_leg_rub'};
%     behaviorClasses.abdominal_cleaning = {'abdominal_cleaning', 'genital_cleaning'};
%     behaviorClasses.other = {'ventral_front_cleaning', 'grooming_attempt', 'first_leg_notum', 'ventral_back_cleaning', ...
%                              'back_leg_grooming_attempt', 'standing_still', 'on_back', 'slip_slash_jump', 'ventral_middle'};

behaviorClasses = struct;
behavList = {};

for i = 1:length(behav_classes)
   bIdx =  find(T.BehaviorClass==behav_classes{i}==1);
   if ~isempty(bIdx)
    % get behaviors for this class
   behavs = T.Behavior(bIdx);                                               % get behaviors belonging to this class
   [~,bind] = sort(T.BehaviorOrder(bIdx));                                  % get and sort behavior order
   behavs = behavs(bind);                                                   % reorder behaviors according to specified order
   behavs = reshape(behavs,1,size(behavs,1));                               % reshape into 1x... array
   
   % get colors for individual behaviors
   classcolor = [T.R1(bIdx(1)) T.G1(bIdx(1)) T.B1(bIdx(1))];
   behavcolors = [T.R2(bIdx) T.G2(bIdx) T.B2(bIdx)];
   behavcolors = behavcolors(bind,:);  % sort to match behaviors
   
   behaviorClasses.(behav_classes{i}).classcolor =  classcolor;
   behaviorClasses.(behav_classes{i}).behaviors = behavs;
   behaviorClasses.(behav_classes{i}).behaviorcolors = behavcolors;
   
   blist{1,1} = behav_classes{i};
   blist{1,2} = classcolor;
   blist(2:1+length(behavs),1) = behavs';
   for ii = 1:length(behavs)
       blist{ii+1,2} = behavcolors(ii,:);
   end

   behavList = [behavList ; blist];
   
   end
    
end


behavTable = T;
end

