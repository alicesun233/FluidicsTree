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
    fprintf('Segmenting Particles')
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
        temp = stationary(k<=[ST.Lifespan],:);
        [tempIdx,tempDist] = dsearchn(moving{k},stationary);
        tempIdx = tempIdx(tempDist<1);
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
        temp = fluidics.ip.freeboundary(moving{k},maskSolidCenters);
        if ~isempty(temp)
            tempIsKept = [temp.Length]>20;
            temp = temp(tempIsKept);
        end
        boundaries{k} = temp;
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
    tempBWDs = cell(tempCC.NumObjects,1);
    for j = 1:tempCC.NumObjects
        temp = false([height width]);
        temp(tempCC.PixelIdxList{j}) = true;
        tempBWDs{j} = bwdist(temp);
    end
    % Computing free boundary cycles
    fprintf('Extracting fronts...\n')
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    fronts = cell(length(listing),1);
    for k = 1:length(listing)
        tempFronts = cell.empty;
        for i = 1:length(boundaries{k})
            temp = fluidics.ip.partition(boundaries{k}(i),tempBWDs);
            tempFronts = vertcat(tempFronts,temp);
        end
        fronts{k} = tempFronts;
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    %treeConfig.Fronts = fronts;
    %treeConfig.TimeDisplacementFronts = datetime;
else
    fronts = treeConfig.Fronts;
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeDisplacementFronts));
clear temp*

%% Step 6: Interface Tracking
fprintf('[Interface Tracking]\n')
if isempty(treeConfig.TimeTracking)
    fprintf('Tracking the boundary cycles\n')
    % Performing interface tracking
    tracker = fluidics.Tracker();
    tracker.FuncEvolve = @(u,v)...
        fluidics.core.dist(u.Circumcenter,v.Circumcenter)>abs(u.Circumradius-v.Circumradius)&&...
        fluidics.core.dist(u.Circumcenter,v.Circumcenter)<u.Circumradius+v.Circumradius;
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        temp = boundaries{k};
        if ~isempty(temp)
            tempIsKept = [temp.Length]>8;
            temp = temp(tempIsKept);
        end
        tracker.linkBack(temp);
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    %treeConfig.TimeTracking = datetime;
else
    
end

% Cleanup
fprintf('Completed: %s\n',datestr(treeConfig.TimeTracking));
clear temp*