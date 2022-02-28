function plot(obj)

% Obtain branches
if ~obj.IsComplete
    branches = obj.complete();
else
    branches = obj.Branches;
end



% Order branches in the order they appear in
[~,I] = sort([branches.FirstFrame]);
branches = branches(I);
rows = zeros(length(branches),1);

% Create initial availability
firstFrame = obj.FirstFrame;
finalFrame = obj.FinalFrame;
totalFrames = finalFrame-firstFrame+1;
blackboard = true(1,totalFrames);

for k = 1:length(branches)
    B = branches(k);
    lifespan = (B.FirstFrame:B.FinalFrame)-firstFrame+1;
    availability = blackboard(:,lifespan);
    firstAvailability = find(all(availability,2),1);
    if ~isempty(firstAvailability)
        rows(k) = firstAvailability;
        blackboard(firstAvailability,lifespan) = false;
    else
        blackboard(end+1,:) = true(1,totalFrames);
        blackboard(end,lifespan) = false;
        rows(k) = size(blackboard,1);
    end
end

% Create figure
figure

% Plot the data points
hold on
for k = 1:length(branches)
    B = branches(k);
    X = B.Frames;
    Y = repmat(rows(k),B.NumItems,1);
    hp = plot(X,Y,'.-');
    
    % Customize datatip
    %NameValuePairs = {'Visible',false};
    %dt = datatip(hp,X(1),Y(1),NameValuePairs{:});
    
    IDs = repmat(B.ID,length(X),1);
    lifespan = sprintf('%d-%d',X([1 end]));
    lifespans = repmat({lifespan},length(X),1);
    
    dtrows = [
        dataTipTextRow('Branch',IDs,'auto');
        dataTipTextRow('Frame','XData','auto');
        dataTipTextRow('Lifespan',lifespans,'auto')];
    
    hp.DataTipTemplate.DataTipRows = dtrows;
end
hold off
axis ij equal
box on
xlabel('Frame')
ylabel('Branch')

% Customize the x-axis
ticks = obj.FirstFrame:obj.FinalFrame;
xlim(ticks([1 end])+[-1 1])
%xticks(ticks(1)-1:ticks(end)+1)
%labels = repmat({''},length(ticks)+2,1);
%labels(2:end-1) = arrayfun(@num2str,ticks,'UniformOutput',false);
%xticklabels(labels)

% Customize the y-axis
ticks = 1:size(availability,1)+1;
ylim(ticks([1 end])+[-1 1])
yticks(ticks(1)-1:ticks(end)+1)
labels = repmat({''},length(ticks)+2,1);
labels(2:end-1) = arrayfun(@num2str,ticks,'UniformOutput',false);
yticklabels(labels)
