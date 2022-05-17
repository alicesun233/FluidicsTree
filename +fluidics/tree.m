%% SCRIPT CONFIGURATION
% Script variables
scriptConfig = struct('FileName','treeConfig.mat',...
              'Folder',fileparts(mfilename('fullpath')));
% Create a .mat file, enable direct write access, and initialize variables
% in the .mat file if they do not exist
scriptConfig.Path = fullfile(scriptConfig.Folder,scriptConfig.FileName);
treeConfig = matfile(scriptConfig.Path,'Writable',true);
if isempty(who(treeConfig,'InputFolder'))
    treeConfig.InputFolder = '';
end
if isempty(who(treeConfig,'InputPattern'))
    treeConfig.InputPattern = [];
end
if isempty(who(treeConfig,'TimeConfigured'))
    treeConfig.TimeConfigured = [];
end
if isempty(who(treeConfig,'TimeValidated'))
    treeConfig.TimeValidated = [];
end
if isempty(who(treeConfig,'TimePhaseSegmented'))
    treeConfig.TimePhaseSegmented = [];
end
if isempty(who(treeConfig,'TimeParticleSegmented'))
    treeConfig.TimeParticleSegmented = [];
end
if isempty(who(treeConfig,'TimeParticleFiltered'))
    treeConfig.TimeParticleFiltered = [];
end
if isempty(who(treeConfig,'TimeFreeBoundary'))
    treeConfig.TimeFreeBoundary = [];
end
if isempty(who(treeConfig,'TimeDisplacementFronts'))
    treeConfig.TimeDisplacementFronts = [];
end
if isempty(who(treeConfig,'TimeTracking'))
    treeConfig.TimeTracking = [];
end
fprintf('Loaded config file: %s\n',treeConfig.Properties.Source)

%% Ask user if they want to use or update current settings

% Any updates?
tempAnyUpdates = false;

% Path to input folder, must point to a folder that exists
tempUpdated = false;
while ~tempUpdated
    tempInput = fluidics.core.prompt(treeConfig.InputFolder,...
        'Use saved path to input folder?',...
        'Enter path to input folder');
    if ~exist(tempInput,'dir')
        disp('The specified path does not exist')
    else
        tempUpdated = true;
    end
end
tempAnyUpdates = tempAnyUpdates||~strcmp(tempInput,treeConfig.InputFolder);
treeConfig.InputFolder = tempInput;

% Pattern of input file name, must not be empty
tempUpdated = false;
while ~tempUpdated
    tempInput = fluidics.core.prompt(treeConfig.InputPattern,...
        'Use saved pattern for input file name?',...
        'Enter pattern for input file name');
    if isempty(tempInput)
        disp('The specified pattern is empty')
    else
        tempUpdated = true;
    end
end
tempAnyUpdates = tempAnyUpdates||~strcmp(tempInput,treeConfig.InputPattern);
treeConfig.InputPattern = tempInput;

% Refresh intermediate config
if tempAnyUpdates
    treeConfig.TimeConfigured = datetime;
    treeConfig.TimeValidated = [];
end

% Cleanup
fprintf('Configuration completed: %s\n',datestr(treeConfig.TimeConfigured));
clear temp*

%% Validation
fprintf('[Input Validation]\n')

% Read a listing
listing = dir(fullfile(treeConfig.InputFolder,treeConfig.InputPattern));
if isempty(treeConfig.TimeValidated)
    % Ensure that all frames are of the same size
    fprintf('Checking frame sizes...\n')
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        tempPath = fullfile(listing(k).folder,listing(k).name);
        tempInfo = imfinfo(tempPath);
        if k == 1
            height = tempInfo.Height;
            width = tempInfo.Width;
        elseif any([tempInfo.Height tempInfo.Width]~=[height width])
            delete(tempBar)
            error('Size mismatch: frame %d ([%d %d]), frame 1 ([%d %d])',...
                k,tempInfo.Height,tempInfo.Width,height,width);
        end
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    treeConfig.TimeValidated = datetime;
elseif ~isempty(listing)
    tempPath = fullfile(listing(1).folder,listing(1).name);
    tempInfo = imfinfo(tempPath);
    height = tempInfo.Height;
    width = tempInfo.Width;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeValidated));
clear temp*

%% Step 1: Segmentation of the solid phase
fprintf('[Phase Segmentation]\n')
if isempty(treeConfig.TimePhaseSegmented)
    fprintf('Solid/Fluid Segmentation...\n')
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        % Read image and compare to the extremum.
        frame = imread(fullfile(listing(k).folder,listing(k).name));
        if k == 1
            imageMinimum = frame;
            imageMaximum = frame;
        else
            imageMinimum = min(imageMinimum,frame);
            imageMaximum = max(imageMaximum,frame);
        end
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Biniarize the range image
    imageRange = imageMaximum-imageMinimum;
    [maskSolid,maskFluid] = fluidics.ip.mask(imageRange);
    % Timestamp results
    treeConfig.ImageMinimum = imageMinimum;
    treeConfig.ImageMaximum = imageMaximum;
    treeConfig.ImageRange = imageRange;
    treeConfig.MaskSolid = maskSolid;
    treeConfig.MaskFluid = maskFluid;
    treeConfig.TimePhaseSegmented = datetime;
else
    % Load results
    imageMinimum = treeConfig.ImageMinimum;
    imageMaximum = treeConfig.ImageMaximum;
    imageRange = treeConfig.ImageRange;
    maskSolid = treeConfig.MaskSolid;
    maskFluid = treeConfig.MaskFluid;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimePhaseSegmented));
clear temp*

%% Step 2: Segmentation of fluorescent particles
fprintf('[Particle Segmentation]\n')
if isempty(treeConfig.TimeParticleSegmented)
    fprintf('Segmenting Particles...\n')
    % Ensure that all frames are of the same size
    particles = cell(length(listing),1);
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        % Binarize input image masked by the fluid phase
        frame = imread(fullfile(listing(k).folder,listing(k).name));
        frame = frame-imageMinimum;
        particles{k} = fluidics.ip.particles(frame,maskFluid).Coordinates;
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    treeConfig.Particles = particles;
    treeConfig.TimeParticleSegmented = datetime;
else
    particles = treeConfig.Particles;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeParticleSegmented));
clear temp*

%% Step 3: Filtering of stationary particles
fprintf('[Stationary Particle Filtering]\n')
if isempty(treeConfig.TimeParticleFiltered)
    % Compute stationary particles from the first few frames
    stationaryCutoff = 20;
    fprintf('Identifying stationary particles (first %d frames)...\n',stationaryCutoff);
    ST = fluidics.ip.stationary(particles,stationaryCutoff);
    % Match and remove stationary particles before they expire
    % For each stationary particle, remove one particle per frame.
    stationary = vertcat(ST.Points);
    moving = particles;
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        tempItems = stationary(k<=[ST.Lifespan],:);
        [tempIdx,tempDists] = dsearchn(moving{k},stationary);
        tempIdx = tempIdx(tempDists<1);
        moving{k}(unique(tempIdx),:) = [];
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    treeConfig.ParticlesStationary = ST;
    treeConfig.ParticlesMoving = moving;
    treeConfig.TimeParticleFiltered = datetime;
else
    ST = treeConfig.ParticlesStationary;
    moving = treeConfig.ParticlesMoving;
    stationary = vertcat(ST.Points);
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeParticleFiltered));
clear temp*

%% Step 4: Extraction of free boundary cycles
fprintf('[Free Boundary Cycles]\n')
if isempty(treeConfig.TimeFreeBoundary)
    % Computing auxiliary points
    [~,maskSolidCenters] = fluidics.ip.mask2circ(maskSolid);
    % Computing free boundary cycles
    fprintf('Extracting long free boundary cycles...\n')
    boundaries = cell(length(listing),1);
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        tempItems = fluidics.ip.freeboundary(moving{k},maskSolidCenters);
        if ~isempty(tempItems)
            tempIsKept = [tempItems.Length]>20;
            tempItems = tempItems(tempIsKept);
        end
        boundaries{k} = tempItems;
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    treeConfig.FreeBoundaries = boundaries;
    treeConfig.TimeFreeBoundary = datetime;
else
    boundaries = treeConfig.FreeBoundaries;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeDisplacementFronts));
clear temp*

%% Step 5: Extraction of displacement fronts
fprintf('[Displacement Fronts]\n')
if isempty(treeConfig.TimeDisplacementFronts)
    % Computing one BWdist for each connected component
    tempCC = bwconncomp(maskSolid);
    tempDists = cell(tempCC.NumObjects,1);
    for j = 1:tempCC.NumObjects
        tempItems = false([height width]);
        tempItems(tempCC.PixelIdxList{j}) = true;
        tempDists{j} = bwdist(tempItems);
    end
    % Computing free boundary cycles
    fprintf('Extracting fronts...\n')
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    fronts = cell(length(listing),1);
    for k = 1:length(listing)
        tempFronts = {};
        for tempCycle = boundaries{k}'
            tempFronts{end+1} = fluidics.ip.partition(tempCycle,tempDists);
        end
        fronts{k} = vertcat(tempFronts{:});
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    treeConfig.Fronts = fronts;
    treeConfig.TimeDisplacementFronts = datetime;
else
    fronts = treeConfig.Fronts;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeDisplacementFronts));
clear temp*

%% Step 6: Interface Tracking
fprintf('[Interface Tracking]\n')
fprintf('Tracking the fronts...\n')
% Performing interface tracking
tracker = fluidics.Tracker();
tracker.FuncEvolve = @(u,v)...
    fluidics.core.dist(u.Circumcenter,v.Circumcenter)<u.Circumradius+v.Circumradius;
tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
for k = 1:length(listing)
    if ~isempty(fronts{k})
        tempFrame = repmat(k,size(fronts{k}));
        tempItems = arrayfun(@fluidics.Item,fronts{k},tempFrame);
        tracker.linkBack(tempItems);
    end
    tempBar.update(k,listing(k).name)
end
delete(tempBar)
frameLimit = tracker.FrameLimit;

% Optimize hanging branches apart by multiple frames
fprintf('Removing hanging branches...\n')
CONST_PROXIMITY = 100;
b = tracker.Branches;
% Identify branches that are not a child of any branch
hanging = ~ismember(1:length(b),unique([vertcat(b.Children).ID]));
ends = [b.FinalItem];
ends = [ends.Value];
for i = find(hanging)
    bi = b(i);
    bipos = bi.FirstItem.Value.Circumcenter;
    func = @(c)fluidics.core.dist(c.Circumcenter,bipos);
    ds = arrayfun(func,ends);
    selected = bi.FirstFrame>[b.FinalFrame];
    selected = selected&ds<CONST_PROXIMITY;
    sel = find(selected);
    if isempty(sel)
        continue
    end
    selff = [b(sel).FinalFrame];
    [~,I] = max(selff);
    connection = sel(I);
    for j = connection
        b(j).pushChild(b(i));
    end
end
% Identify branches that do not have a child
hanging = cellfun(@isempty,{b.Children});
ends = [b.FirstItem];
ends = [ends.Value];
for i = find(hanging)
    bi = b(i);
    bipos = bi.FinalItem.Value.Circumcenter;
    func = @(c)fluidics.core.dist(c.Circumcenter,bipos);
    ds = arrayfun(func,ends);
    selected = bi.FinalFrame<[b.FirstFrame];
    selected = selected&ds<CONST_PROXIMITY;
    sel = find(selected);
    if isempty(sel)
        continue
    end
    selff = [b(sel).FirstFrame];
    [~,I] = min(selff);
    connection = sel(I);
    for j = connection
        b(i).pushChild(b(j));
    end
end
%  Topological analysis begins now
something_changed = true;
while something_changed
    something_changed = false;
    b = tracker.Branches;
    % Detect if anything can be shortened
    for i = 1:length(b)
        if length(b(i).Children)~=1
            continue
        end
        if length(b(i).Children.Parents)~=1
            continue
        end
        bi = b(i);
        bj = b(i).Children;
        fprintf('%d absorbs %d, %d branches left\n',bi.ID,bj.ID,length(b)-1);
        bi.absorb(bj);
        tracker.remove(bj);
        something_changed = true;
        break
    end
    if something_changed
        continue
    end
    % Detect conflicting events
    for i = 1:length(b)
        bi = b(i);
        if length(bi.Children)~=2
            continue
        end
        for bc = fluidics.core.mat2row(bi.Children)
            if length(bc.Parents)~=2
                continue
            end
            bp = bc.Parents(bc.Parents~=b(i));
            bo = bi.Children(bi.Children~=bc);
            if bc.FirstFrame ~= bo.FirstFrame
                continue
            end
            % bi  bc
            %   ZX
            % bp  bo
            fully_connected = ismember(bo,bp.Children);
            fprintf('            [%4d-%d\n',bi.ID,bc.ID)
            fprintf('ZX detected:[    ')
            if fully_connected
                fprintf('X');
            else
                fprintf('Z');
            end
            fprintf('\n            [%4d-%d\n',bp.ID,bo.ID)

            % if X, resolve to one of the two configurations
            % Configuration 1: bi-bc
            %
            %                  bp-bo
            % Configuration 2: bi bc
            %                    X
            %                  bp bo
            % by choosing the one with the smaller sum
            d1 = fluidics.core.dist(bi.FinalItem.Value.Circumcenter,...
                bc.FirstItem.Value.Circumcenter)+...
                fluidics.core.dist(bp.FinalItem.Value.Circumcenter,...
                bo.FirstItem.Value.Circumcenter);
            d2 = fluidics.core.dist(bi.FinalItem.Value.Circumcenter,...
                bo.FirstItem.Value.Circumcenter)+...
                fluidics.core.dist(bp.FinalItem.Value.Circumcenter,...
                bc.FirstItem.Value.Circumcenter);
            if d1<d2
                % delink bi           bc
                %          \   and   /
                %           bo     bp
                bi.Children(bi.Children==bo) = [];
                bp.Children(bp.Children==bc) = [];
                bo.Parents(bo.Parents==bi) = [];
                bc.Parents(bc.Parents==bp) = [];
                % link bi-bc and bp-bo
                bi.Children = unique([bi.Children;bc]);
                bp.Children = unique([bp.Children;bo]);
                bo.Parents = unique([bo.Parents;bp]);
                bc.Parents = unique([bc.Parents;bi]);
            else
                % delink bi-bc
                % and
                %        bp-bo
                bi.Children(bi.Children==bc) = [];
                bp.Children(bp.Children==bo) = [];
                bc.Parents(bc.Parents==bi) = [];
                bo.Parents(bo.Parents==bp) = [];
                % link bi           bc
                %        \   and   /
                %         bo     bp
                bi.Children = unique([bi.Children;bo]);
                bp.Children = unique([bp.Children;bc]);
                bo.Parents = unique([bo.Parents;bi]);
                bc.Parents = unique([bc.Parents;bp]);
            end

            something_changed = true;
            break
        end
        if something_changed
            break
        end
    end
    if something_changed
        continue
    end
    % Detect porous branches
    for i = 1:length(b)
        bi = b(i);
        if bi.NumItems/(bi.FinalFrame-bi.FirstFrame+1)>.5
            continue
        end
        for bc = fluidics.core.mat2row(bi.Children)
            bc.Parents(bc.Parents==bi) = [];
        end
        for bp = fluidics.core.mat2row(bi.Parents)
            bp.Children(bp.Children==bi) = [];
        end
        fprintf('Porous branch %d removed, %d branches left\n',bi.ID,length(b)-1)
        tracker.remove(bi)
        something_changed = true;
        if something_changed
            break
        end
    end
    if something_changed
        continue
    end
    % Remove spurious branches
    for i = 1:length(b)
        bi = b(i);
        if ~isempty(bi.Children)
            continue
        end
        if ~isempty(bi.Parents)
            continue
        end
        fprintf('Spurious branch %d removed, %d branches left\n',bi.ID,length(b)-1)
        tracker.remove(bi)
        something_changed = true;
        if something_changed
            break
        end
    end
    if something_changed
        continue
    end
    % Merge parallel branches
    for i = 1:length(b)
        bi = b(i);
        if length(bi.Children)<2
            continue
        end
        if length(unique([bi.Children.FirstFrame]))~=1
            continue
        end
        if length(unique([bi.Children.FinalFrame]))~=1
            continue
        end
        fprintf('Merging branches: %d',bi.Children(1).ID)
        fprintf(', %d',[bi.Children(2:end).ID])
        fprintf('\n')
        % Keep the first branch and merge all items of other branches back
        % into this first branch
        items = vertcat(bi.Children.Items);
        items_firstframe = min([items.Frame]);
        items_finalframe = max([items.Frame]);
        for j = 1:length(bi.Children)
            bi.Children(j).Items(:) = [];
        end
        for k = items_firstframe:items_finalframe
            to_merge = [items([items.Frame]==k).Value];
            to_merge = {to_merge.Points};
            merged = to_merge{1};
            while length(to_merge)>1
                ds = zeros(4,length(to_merge)-1);
                for j = 2:length(to_merge)
                    % 1 NOFLIP J NOFLIP
                    ds(1,j-1) = fluidics.core.dist(merged(end,:),to_merge{j}(1,:));
                    % 2 NOFLIP J   FLIP
                    ds(2,j-1) = fluidics.core.dist(merged(end,:),to_merge{j}(end,:));
                    % 1   FLIP J NOFLIP
                    ds(3,j-1) = fluidics.core.dist(merged(1,:),to_merge{j}(1,:));
                    % 2   FLIP J   FLIP
                    ds(4,j-1) = fluidics.core.dist(merged(1,:),to_merge{j}(end,:));
                end
                % Search for the cheapest configuration
                [~,I] = min(ds,[],'all','linear');
                [f,j] = ind2sub(size(ds),I);
                % Concatenate
                if f==3||f==4
                    merged = flipud(merged);
                end
                if f==1||f==3
                    % No flip
                    merged = [merged;to_merge{j+1}];
                else
                    % Flip
                    merged = [merged;flipud(to_merge{j+1})];
                end
                to_merge(j+1) = [];
            end
            [c,r] = fluidics.core.mincirc(merged);
            merged_front = struct('Points',      merged,...
                                  'EdgeCount',   size(merged,1),...
                                  'Closed',      false,...
                                  'Circumcenter',c,...
                                  'Circumradius',r);
            bi.Children(1).Items = [bi.Children(1).Items;fluidics.Item(merged_front,k)]; 
        end
        delete(items)
        % Remove b(i).Children(2:end) from parents and children
        for bc = fluidics.core.mat2row(bi.Children(2:end))
            for bcc = fluidics.core.mat2row(bc.Children)
                bcc.Parents(bcc.Parents==bc) = [];
            end
            tracker.remove(bc)
        end
        fprintf('%d branches left\n',bi.ID,length(b)-(length(bi.Children)-1))
        bi.Children(2:end) = [];

        something_changed = true;
        if something_changed
            break
        end
    end
    if something_changed
        continue
    end
    % Remove still branches
    for i = 1:length(b)
        bi = b(i);
        dx = fluidics.core.dist(bi.FirstItem.Value.Circumcenter,...
                                bi.FinalItem.Value.Circumcenter);
        dt = bi.FinalFrame-bi.FirstFrame;
        r = dx/dt;
        fprintf('%g\n',r)
    end
    if something_changed
        continue
    end
end

%%
fluidics.EvolutionChart('Data',tracker,...
    'Image',im2uint8(maskSolid)/2,...
    'FrameLimit',frameLimit,...
    'Frame',frameLimit(1));

%%

% Cleanup
fprintf('Completed: %s\n',datetime);
clear temp*
