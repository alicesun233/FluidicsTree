classdef EvolutionChart < matlab.graphics.chartcontainer.ChartContainer
    properties
        % Background image
        Image = uint8.empty
        % Left and right limit of the frame window
        FrameLimit(1,2) double = nan(1,2)
        % Current frame
        Frame(1,1) double = 1
        % Current branch
        Branch(1,1) double = 1
    end
    
    properties (Dependent)
        % Summary of branches
        Data
    end
    
    properties (SetAccess=protected)
        % Copy of data to save
        SavedData = cell.empty
        % Copy of displacement fronts
        SavedFronts = []
        % Copy of children information
        SavedChildren = {}
        % The last time when data is updated
        TimeUpdatedData(1,1) datetime = NaT
        TimeUpdatedFrame(1,1) datetime = NaT
        TimePlot(1,1) datetime = NaT
    end
    
    properties (Access=private,Transient,NonCopyable)
        % Axes: Displacement fronts in current frame
        TopLeftAxes matlab.graphics.axis.Axes
        TopLeftImage matlab.graphics.primitive.Image
        TopLeftLines matlab.graphics.chart.primitive.Line
        % Axes: Displacement fronts in current branch
        TopRightAxes matlab.graphics.axis.Axes
        TopRightImage matlab.graphics.primitive.Image
        TopRightLines matlab.graphics.chart.primitive.Line
        % Axes: Zoomed-in view of evolution
        MiddleAxes matlab.graphics.axis.Axes
        MiddleLines matlab.graphics.chart.primitive.Line
        MiddleArrows matlab.graphics.chart.primitive.Line
        % Axes: Global view of evolution
        BottomAxes matlab.graphics.axis.Axes
        BottomLines matlab.graphics.chart.primitive.Line
        BottomArrows matlab.graphics.chart.primitive.Line
        FrameWindow matlab.graphics.primitive.Patch
        FrameLine matlab.graphics.chart.decoration.ConstantLine
    end
    
    methods
        function set.Data(obj,tracker)
            validateattributes(tracker,{'fluidics.Tracker'},{'scalar'});
            obj.SavedData = tracker.Summary;
            % Compute saved fronts
            branches = tracker.Branches;
            IDs = repelem([branches.ID],cellfun(@length,{branches.Items}))';
            items = vertcat(branches.Items);
            frames = [items.Frame]';
            fronts = [items.Value]';
            points = {fronts.Points}';
            for k = 1:length(points)
                if fronts(k).Closed
                    points{k}(end+1,:) = points{k}(1,:);
                end
            end
            obj.SavedFronts = struct(...
                'Branch',num2cell(IDs),...
                'Frame',num2cell(frames),...
                'Points',points);
            % Compute saved parent-children relation
            func = @(c)[c.ID];
            PCs = cellfun(func,{branches.Children},'UniformOutput',false);
            IDs = repelem(1:length(branches),cellfun(@numel,PCs));
            obj.SavedChildren = [IDs;horzcat(PCs{:})]';
            % Update timestamp
            obj.TimeUpdatedData = datetime;
        end
        
        function data = get.Data(obj)
            data = obj.SavedData;
        end
        
        function set.Frame(obj,frame)
            obj.Frame = frame;
            obj.TimeUpdatedFrame = datetime;
        end
    end
    
    methods (Access=protected)
        function setup(obj)
            % Create a tiling
            tcl = getLayout(obj);
            tcl.GridSize = [5 2];
            % Top left axes
            obj.TopLeftAxes = nexttile(tcl,1,[3 1]); % Height: 60%
            % Top right axes
            obj.TopRightAxes = nexttile(tcl,2,[3 1]);% Height: 60%
            % Middle axes
            obj.MiddleAxes = nexttile(tcl,7,[1 2]);  % Height: 20%
            axis(obj.MiddleAxes,'ij')
            % Bottom axes
            obj.BottomAxes = nexttile(tcl,9,[1 2]);  % Height: 20%
            axis(obj.BottomAxes,'ij')
            
            % Add a shared toolbar on the layout, which removes the
            % toolbar from the individual axes
            axtoolbar(tcl,'default');
            
            % Create a plot for the displacement fronts
            obj.TopLeftImage = imshow(uint8.empty,...
                'Parent',obj.TopLeftAxes);
            set(obj.TopLeftImage,'HitTest','off')
            
            % Create a plot for the timelapse of select branch
            obj.TopRightImage = imshow(uint8.empty,...
                'Parent',obj.TopRightAxes);
            set(obj.TopRightImage,'HitTest','off')
            
            % Create a plot for the zoomed-in evolution graph
            % Disable HitTest to enable ButtonDownFcn
            obj.MiddleLines = plot(obj.MiddleAxes,NaN,NaN);
            
            % Create a plot for the overview of the volution graph
            % Disable HitTest to enable ButtonDownFcn
            obj.BottomLines = plot(obj.BottomAxes,NaN,NaN,'HitTest','off');
            % Create a rectangular patch to show the current frame window
            % Disable HitTest to enable ButtonDownFcn
            obj.FrameWindow = patch(obj.BottomAxes,...
                'Faces',1:4,...
                'Vertices',NaN(4,2),...
                'FaceColor','cyan',...
                'FaceAlpha',0.3,...
                'EdgeColor','cyan',...
                'EdgeAlpha',0.7,...
                'HitTest','off');
            % Create a current frame line
            obj.FrameLine = xline(obj.BottomAxes,obj.Frame,'--m');
            % Constrain middle axes panning/zooming to only the X-dimension
            obj.MiddleAxes.Interactions = [
                panInteraction('Dimensions','x');
                rulerPanInteraction('Dimensions','x');
                zoomInteraction('Dimensions','x')];
            % Disable pan/zoom on the bottom axes
            obj.BottomAxes.Interactions = [];
            % Add a listener to XLim to respond to zoom events
            addlistener(obj.MiddleAxes,...
                'XLim','PostSet',@(~,~)panZoom(obj));
            % Add a callback for clicks on the bottom axes
            obj.BottomAxes.ButtonDownFcn = @(~,~)bottomAxesClick(obj);
        end
        
        function update(obj)
            % Update objects if the plot is newer
            if isnat(obj.TimePlot)||obj.TimePlot<obj.TimeUpdatedData
                % Update the top left image
                obj.TopLeftImage.CData = obj.Image;
                % Update the top right image
                obj.TopRightImage.CData = obj.Image;
                % Update children arrows in the middle axes
                numArrows = length(obj.MiddleArrows);
                delete(obj.MiddleArrows(numArrows+1:end))
                obj.MiddleArrows(numArrows+1:end) = [];
                for k = 1:length(obj.SavedChildren)
                    bParent = obj.SavedChildren(k,1);
                    bChild = obj.SavedChildren(k,end);
                    X = [obj.Data(bParent).Frames(end);
                         obj.Data(bChild).Frames(1)];
                    Y = [obj.Data(bParent).Number;
                         obj.Data(bChild).Number];
                    if k <= numArrows
                        % Update data to existing arrows
                        h = obj.MiddleArrows(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new arrows
                        hold(obj.MiddleAxes,'on')
                        h = plot(obj.MiddleAxes,X,Y,'r:','HitTest','off');
                        obj.MiddleArrows(k) = h;
                    end
                end
                % Update detailed lines in the middle axes
                numFronts = length(obj.MiddleLines);
                delete(obj.MiddleLines(numFronts+1:end))
                obj.MiddleLines(numFronts+1:end) = [];
                for k = 1:length(obj.Data)
                    X = obj.Data(k).Frames;
                    Y = repmat(obj.Data(k).Number,size(X));
                    if k <= numFronts
                        % Update data to existing lines
                        h = obj.MiddleLines(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new lines
                        hold(obj.MiddleAxes,'on')
                        h = plot(obj.MiddleAxes,X,Y,'.-');
                        obj.MiddleLines(k) = h;
                    end
                end
                updateMiddleDataTipText(obj.MiddleLines,obj.Data)
                hold(obj.MiddleAxes,'off')
                ylim(obj.MiddleAxes,[0 max([obj.Data.Number])+1])
                % Update children lines in the bottom axes
                numArrows = length(obj.BottomArrows);
                delete(obj.BottomArrows(numArrows+1:end))
                obj.BottomArrows(numArrows+1:end) = [];
                for k = 1:length(obj.SavedChildren)
                    bParent = obj.SavedChildren(k,1);
                    bChild = obj.SavedChildren(k,end);
                    X = [obj.Data(bParent).Frames(end);
                         obj.Data(bChild).Frames(1)];
                    Y = [obj.Data(bParent).Number;
                         obj.Data(bChild).Number];
                    if k <= numArrows
                        % Update data to existing arrows
                        h = obj.BottomArrows(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new arrows
                        hold(obj.BottomAxes,'on')
                        h = plot(obj.BottomAxes,X,Y,'r:','HitTest','off');
                        obj.BottomArrows(k) = h;
                    end
                end
                % Update simple lines in the bottom axes
                numFronts = length(obj.BottomLines);
                delete(obj.BottomLines(numFronts+1:end))
                obj.BottomLines(numFronts+1:end) = [];
                for k = 1:length(obj.Data)
                    X = obj.Data(k).Frames([1 end]);
                    Y = repmat(obj.Data(k).Number,size(X));
                    if k <= numFronts
                        % Update data to existing lines
                        h = obj.BottomLines(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new lines
                        hold(obj.BottomAxes,'on')
                        h = plot(obj.BottomAxes,X,Y,'.-','HitTest','off');
                        obj.BottomLines(k) = h;
                    end
                end
                hold(obj.BottomAxes,'off')
                ylim(obj.BottomAxes,[0 max([obj.Data.Number])+1])
            end
            
            % Update frame window
            % Update the middle axes limits
            obj.MiddleAxes.YLimMode = 'auto';
            if obj.FrameLimit(1) < obj.FrameLimit(2)
                obj.MiddleAxes.XLim = obj.FrameLimit;
            else
                % Current frame limits are invalid, so set XLimMode to auto
                % and let the axes calculate limits based on available data
                obj.MiddleAxes.XLimMode = 'auto';
                obj.FrameLimit = obj.MiddleAxes.XLim;
            end
            % Update frame line
            set(obj.FrameLine,'Value',obj.Frame)
            
            % Update frame window to reflect the new time limits
            xLimits = ruler2num(obj.FrameLimit,obj.BottomAxes.XAxis);
            yLimits = obj.BottomAxes.YLim;
            
            obj.FrameWindow.Vertices = [xLimits([1 1 2 2]); yLimits([1 2 2 1])]';
            
            % Update top left and top right images
            if isnat(obj.TimePlot)||obj.TimePlot<obj.TimeUpdatedFrame
                % Update lines: top left
                isCurrentFrame = [obj.SavedFronts.Frame]==obj.Frame;
                fronts = obj.SavedFronts(isCurrentFrame);
                numFronts = length(fronts);
                delete(obj.TopLeftLines(numFronts+1:end))
                obj.TopLeftLines(numFronts+1:end) = [];
                numLines = length(obj.TopLeftLines);
                for k = 1:length(fronts)
                    X = fronts(k).Points(:,1);
                    Y = fronts(k).Points(:,2);
                    if k <= numLines
                        % Update data to existing lines
                        h = obj.TopLeftLines(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new lines
                        hold(obj.TopLeftAxes,'on')
                        h = plot(obj.TopLeftAxes,X,Y,'.-');
                        obj.TopLeftLines(k) = h;
                    end
                end
                hold(obj.TopLeftAxes,'off')
                updateTopLeftDataTipText(obj.TopLeftLines,fronts)
                % Update lines: top right
                isCurrentBranch = [obj.SavedFronts.Branch]==obj.Branch;
                fronts = obj.SavedFronts(isCurrentBranch);
                numFronts = length(fronts);
                delete(obj.TopRightLines(numFronts+1:end))
                obj.TopRightLines(numFronts+1:end) = [];
                numLines = length(obj.TopRightLines);
                for k = 1:length(fronts)
                    X = fronts(k).Points(:,1);
                    Y = fronts(k).Points(:,2);
                    if k <= numLines
                        % Update data to existing lines
                        h = obj.TopRightLines(k);
                        set(h,'XData',X,'YData',Y)
                    else
                        % Update data to new lines
                        hold(obj.TopRightAxes,'on')
                        h = plot(obj.TopRightAxes,X,Y,'.-');
                        obj.TopRightLines(k) = h;
                    end
                end
                hold(obj.TopRightAxes,'off')
                updateTopRightDataTipText(obj.TopRightLines,fronts)
            end
            % Enable the data cursor mode
            dcm = datacursormode(gcf);
            set(dcm,'Enable',true);
            % Add a callback for return keys
            % Ref: https://undocumentedmatlab.com/articles/enabling-user-callbacks-during-zoom-pan
            % Ref: https://www.mathworks.com/matlabcentral/answers/251339-re-enable-keypress-capture-in-pan-or-zoom-mode
            % FIXME - uigetmodemanager is undocumented (DJL)
            uimm = uigetmodemanager(gcf);
            try
                % this should work for versions of MATLAB <= R2014a
                set(uimm.WindowListenerHandles,'Enable','off');
            catch
                % this works in R2014b, and maybe beyond; your mileage may vary
                [uimm.WindowListenerHandles.Enabled] = deal(false);
            end
            % these lines are common to all versions up to R2014b (and maybe beyond)
            set(gcf,'WindowKeyPressFcn',@(~,event)keyPress(obj,event))
            set(gcf,'KeyPressFcn',[])
            % Update time of plot
            obj.TimePlot = datetime;
        end
        
        function keyPress(obj,event)
            if strcmp(event.Key,'return')
                dcm = datacursormode(gcf);
                info = getCursorInfo(dcm);
                if isempty(info)||length(info)>1
                    commandwindow
                    return
                end
                target = info.Target;
                rows = target.DataTipTemplate.DataTipRows;
                if strcmp(rows(1).Value,'XData')
                    obj.Branch = target.XData(info.DataIndex);
                elseif strcmp(rows(1).Value,'YData')
                    obj.Branch = target.YData(info.DataIndex);
                else
                    obj.Branch = rows(1).Value(info.DataIndex);
                end
                if strcmp(rows(2).Value,'XData')
                    obj.Frame = target.XData(info.DataIndex);
                elseif strcmp(rows(2).Value,'YData')
                    obj.Frame = target.YData(info.DataIndex);
                else
                    obj.Frame = rows(2).Value(info.DataIndex);
                end
            end
        end
        
        function panZoom(obj)
            % When XLim on the middle axes changes,
            % update the frame limits
            obj.FrameLimit = obj.MiddleAxes.XLim;
        end
        
        function middleAxesClick(obj)
            obj
        end
        
        function bottomAxesClick(obj)
            % When clicking on the bottom axes, recenter the time limits.
            % Find the center of the click using CurrentPoint.
            center = obj.BottomAxes.CurrentPoint(1,1);
            % Convert from numeric units into datetime using num2ruler.
            center = num2ruler(center,obj.BottomAxes.XAxis);
            % Find the width of the current time limits.
            width = diff(obj.FrameLimit);
            % Recenter the current time limits.
            obj.FrameLimit = center+[-1 1]*width/2;
        end
    end
end

function updateTopLeftDataTipText(lines,fronts)
for k = 1:length(lines)
    % Obtain current 1-1 correspondence
    front = fronts(k);
    line = lines(k);
    % Obtain data
    branch = repmat(front.Branch,size(front.Points,1),1);
    frames = repmat(front.Frame,size(front.Points,1),1);
    indices = (1:size(front.Points,1))';
    func = @(i,x,y)sprintf('%g(%g,%g)',i,x,y);
    XY = fluidics.core.col2cell(front.Points);
    points = arrayfun(func,indices,XY{:},'UniformOutput',false);
    % Branch/Frame/Index/Point
    line.DataTipTemplate.DataTipRows = [
        dataTipTextRow('Branch',branch);
        dataTipTextRow('Frame',frames);
        dataTipTextRow('Point',points)];
end
end

function updateTopRightDataTipText(lines,fronts)
lifespan = sprintf('%d-%d',[fronts([1 end]).Frame]);
for k = 1:length(lines)
    % Obtain current 1-1 correspondence
    front = fronts(k);
    line = lines(k);
    % Obtain data
    branch = repmat(front.Branch,size(front.Points,1),1);
    frames = repmat(front.Frame,size(front.Points,1),1);
    lspans = repmat({lifespan},size(front.Points,1),1);
    indices = (1:size(front.Points,1))';
    func = @(i,x,y)sprintf('%g(%g,%g)',i,x,y);
    XY = fluidics.core.col2cell(front.Points);
    points = arrayfun(func,indices,XY{:},'UniformOutput',false);
    % Branch/Frame/Lifespan/Index/Point
    line.DataTipTemplate.DataTipRows = [
        dataTipTextRow('Branch',branch);
        dataTipTextRow('Frame',frames);
        dataTipTextRow('Lifespan',lspans);
        dataTipTextRow('Point',points)];
end
end

function updateMiddleDataTipText(lines,data)
branches = [data.ID];
for k = 1:length(lines)
    line = lines(k);
    % Branch/Frame/Lifespan
    IDs = repmat(branches(k),length(line.XData),1);
    lifespan = sprintf('%d-%d',line.XData([1 end]));
    lifespans = repmat({lifespan},length(line.XData),1);
    line.DataTipTemplate.DataTipRows = [
        dataTipTextRow('Branch',IDs);
        dataTipTextRow('Frame','XData');
        dataTipTextRow('Lifespan',lifespans)];
end
end
