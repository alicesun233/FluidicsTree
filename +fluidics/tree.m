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

% Read a listing
listing = dir(fullfile(treeConfig.InputFolder,treeConfig.InputPattern));

% Skip if already validated
if isempty(treeConfig.TimeValidated)
    % Ensure that all frames are of the same size
    fprintf('Checking image size:\n')
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
fprintf('Input validation completed: %s\n',datestr(treeConfig.TimeValidated));
clear temp*

%% Step 1: Segmentation of the solid phase

% Skip if the solid phase has been found
if isempty(treeConfig.TimePhaseSegmented)
    fprintf('Solid/Fluid phase segmentation:\n')
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
fprintf('Segmentation of phases completed: %s\n',datestr(treeConfig.TimePhaseSegmented));
clear temp*

%% Step 2: Segmentation of fluorescent particles
if isempty(treeConfig.TimeParticleSegmented)
    particles = repmat(struct('Coordinates',[]),length(listing),1);
    % Ensure that all frames are of the same size
    fprintf('Particle segmentation:\n')
    tempBar = fluidics.ui.progress(0,length(listing),'Initializing');
    for k = 1:length(listing)
        % Binarize input image masked by the fluid phase
        frame = imread(fullfile(listing(k).folder,listing(k).name));
        frame = frame-imageMinimum;
        particles(k) = fluidics.ip.particles(frame,maskFluid);
        tempBar.update(k,listing(k).name)
    end
    delete(tempBar)
    % Timestamp results
    treeConfig.Particles = frames;
    treeConfig.TimeParticleSegmented = datetime;
else
    particles = treeConfig.Particles;
end

% Cleanup
fprintf('Particle segmentation completed: %s\n',datestr(treeConfig.TimeParticleSegmented));
clear temp*
