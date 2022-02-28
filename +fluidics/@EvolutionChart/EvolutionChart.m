classdef EvolutionChart < matlab.graphics.chartcontainer.ChartContainer
    properties
        Image = uint8.empty
        Fronts = cell.empty
        FrameLimit(1,2) double = nan(1,2)
        Frame(1,1) double {mustBeInteger} = 1
    end
    
    properties (Dependent)
        Data
    end
    
    properties (SetAccess=protected)
        SavedData = cell.empty
    end
    
    properties (Access=private,Transient,NonCopyable)
        TopLeftAxes matlab.graphics.axis.Axes
        TopRightAxes matlab.graphics.axis.Axes
        MiddleAxes matlab.graphics.axis.Axes
        MiddleLines
        BottomAxes matlab.graphics.axis.Axes
        BottomLines
        FrameWindow matlab.graphics.primitive.Patch
    end
    
    methods
        function set.Data(obj,tracker)
            validateattributes(tracker,{'fluidics.Tracker'},{'scalar'});
            obj.SavedData = tracker.Summary;
        end
        
        function data = get.Data(obj)
            data = obj.SavedData;
        end
    end
    
    methods (Access=protected)
        function setup(obj)
            % Create three axes
            tcl = getLayout(obj);
            tcl.GridSize = [5 2];
            obj.TopLeftAxes = nexttile(tcl,1,[3 1]); % Height: 60%
            obj.TopRightAxes = nexttile(tcl,2,[3 1]); % Height: 60%
            obj.MiddleAxes = nexttile(tcl,7,[1 2]);  % Height: 20%
            obj.BottomAxes = nexttile(tcl,9,[1 2]);  % Height: 20%
            
            % Add a shared toolbar on the layout, which removes the
            % toolbar from the individual axes
            axtoolbar(tcl,'default');
            
            % Create a plot for the displacement fronts
            imshow(uint8.empty,'Parent',obj.TopLeftAxes);
            
            % Create a plot for the timelapse of select branch
            imshow(uint8.empty,'Parent',obj.TopRightAxes);
            
            % Create a plot for the zoomed-in evolution graph
            % Disable HitTest to enable ButtonDownFcn
            plot(obj.MiddleAxes,NaN,NaN,'HitTest','off');
            
            % Create a plot for the overview of the volution graph
            % Disable HitTest to enable ButtonDownFcn
            plot(obj.BottomAxes,NaN,NaN,'HitTest','off');
            
            % Create a rectangular patch to show the current frame window
            % Disable HitTest to enable ButtonDownFcn
            obj.FrameWindow = patch(obj.BottomAxes,...
                'Faces',1:4,...
                'Vertices',NaN(4,2),...
                'FaceColor','cyan',...
                'FaceAlpha',0.3,...
                'EdgeColor','none',...
                'HitTest','off');
            
            % Constrain middle axes panning/zooming to only the X-dimension
            obj.MiddleAxes.Interactions = [
                panInteraction('Dimensions','x');
                rulerPanInteraction('Dimensions','x');
                zoomInteraction('Dimensions','x')];
            
            % Disable pan/zoom on the bottom axes
            obj.BottomAxes.Interactions = [];
            
            % Add a listener to XLim to respond to zoom events.
            addlistener(obj.MiddleAxes,...
                'XLim','PostSet',@(~,~)panZoom(obj));
            
            % Add a callback for clicks on the bottom axes.
            obj.BottomAxes.ButtonDownFcn = @(~,~)click(obj);
        end
        
        function update(obj)
            % Update the image on the top left axis
            NameValuePairs = {'Parent',obj.TopLeftAxes};
            imshow(obj.Image,NameValuePairs{:})
            % Draw the displacement fronts
            fronts = obj.Fronts{obj.Frame};
            hold(obj.TopLeftAxes,'on')
            for i = 1:length(fronts)
                points = fronts(i).Points;
                if fronts(i).Closed
                    points(end+1,:) = points(1,:);
                end
                XY = fluidics.core.col2cell(points);
                plot(obj.TopLeftAxes,XY{:},'.-','MarkerSize',9)
            end
            hold(obj.TopLeftAxes,'off')
            
            % Update the image on the top right axis
            NameValuePairs = {'Parent',obj.TopRightAxes};
            imshow(obj.Image,NameValuePairs{:})
            
            % Update branches on both the middle axes
            obj.MiddleLines = cell(length(obj.Data),1);
            for k = 1:length(obj.Data)
                info = obj.Data(k);
                X = info.Frames;
                Y = repmat(info.Number,length(X),1);
                obj.MiddleLines{k} = plot(obj.MiddleAxes,X,Y,'.-');
                hold(obj.MiddleAxes,'on')
            end
            hold(obj.MiddleAxes,'off')
            
            % Update branches on the bottom axes with lower resolution
            obj.BottomLines = cell(length(obj.Data),1);
            for k = 1:length(obj.Data)
                info = obj.Data(k);
                X = info.Frames([1 end]);
                Y = repmat(info.Number,2,1);
                NameValuePairs = {'Color',obj.MiddleLines{k}.Color};
                obj.BottomLines{k} = plot(obj.BottomAxes,X,Y,'.-',...
                    NameValuePairs{:});
                hold(obj.BottomAxes,'on')
            end
            hold(obj.BottomAxes,'off')
            
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
            
            % Update frame window to reflect the new time limits
            xLimits = ruler2num(obj.FrameLimit,obj.BottomAxes.XAxis);
            yLimits = obj.BottomAxes.YLim;
            hold(obj.MiddleAxes,'on')
            obj.FrameWindow = patch(obj.BottomAxes,...
                'Faces',1:4,...
                'Vertices',[xLimits([1 1 2 2]); yLimits([1 2 2 1])]',...
                'FaceColor','cyan',...
                'FaceAlpha',0.3,...
                'EdgeColor','none',...
                'HitTest','off');
            hold(obj.BottomAxes,'off')
            
            % Add a callback for clicks on the bottom axes.
            obj.BottomAxes.ButtonDownFcn = @(~,~)click(obj);
        end
        
        function panZoom(obj)
            % When XLim on the middle axes changes,
            % update the frame limits
            obj.FrameLimit = obj.MiddleAxes.XLim;
        end
        
        function click(obj)
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


function updateDataTipTemplate(obj, tbl)
% Create a dataTipTextRow for each variable in the timetable.
timeVariable = tbl.Properties.DimensionNames{1};
rows = dataTipTextRow(timeVariable, tbl.(timeVariable));
for n = 1:numel(tbl.Properties.VariableNames)
    rows(n+1,1) = dataTipTextRow(...
        tbl.Properties.VariableNames{n}, tbl{:,n});
end
obj.DataTipTemplate.DataTipRows = rows;

end

function mustHaveOneNumericVariable(tbl)

% Validation function for Data property.
S = vartype('numeric');
if width(tbl(:,S)) < 1
    error('TimeTableChart:InvalidTable', ...
        'Table must have at least one numeric variable.')
end

end