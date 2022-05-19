%%%%%%%%%%%%%%%%%%%%%%%%%%
% Jindi Sun & Ziqiang Li %
%%%%%%%%%%% & %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% [P]                    [I]    a            [V]                          %
%           r  i            m                          i          r       %
%         a        l                    e          l c                y   %
%             t      e             g                o      e              %
%                c                              e         m   t           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% File code: B
% File memo: Forward Difference

% {START} -> (B1) -> (B2) -> (B3) -> (B4) -> (B5)

%% (B1) Particle Image Velocimetry Toolkit - Main Workflow File
fprintf('Module B1\n');
% Reset the workspace
clearvars -except DATA_PATH
set(0,'defaultTextInterpreter','none');

tempUpdated = false;
while ~tempUpdated
    tempInput = fluidics.core.prompt('',...
        'Use saved path to input folder?',...
        'Enter path to input folder');
    if ~exist(tempInput,'dir')
        disp('The specified path does not exist')
    else
        tempUpdated = true;
    end
end
DATA_PATH = tempInput;

tempUpdated = false;
while ~tempUpdated
    tempInput = fluidics.core.prompt('',...
        'Use saved pattern for input file name?',...
        'Enter pattern for input file name');
    if isempty(tempInput)
        disp('The specified pattern is empty')
    else
        tempUpdated = true;
    end
end
DATA_PATTERN = tempInput;

% Data path
if ~exist('DATA_PATH','var')
    DATA_PATH = fullfile('C:','user','20211027','data');
end

% Query directory and reorder files based on numbering
list = dir(fullfile(DATA_PATH,DATA_PATTERN));

% Calculate mask
 for k = 1:length(list)
        % Read image and compare to the extremum.
        frame = imread(fullfile(list(k).folder,list(k).name));
        if k == 1
            imageMinimum = frame;
            imageMaximum = frame;
        else
            imageMinimum = min(imageMinimum,frame);
            imageMaximum = max(imageMaximum,frame);
        end
 end
    % Biniarize the range image
    imageRange = imageMaximum-imageMinimum;
    mask = fluidics.ip.mask(imageRange);

%% (B2) Loads the first frame and query frame dimensions
fprintf('Module B2\n');
% Keep two frames only--the current and the next
frames = cell(1);
item = list(1);
path = fullfile(item.folder,item.name);
frame = imread(path);
% If image is 3D, extract its blue channel
if ndims(frame)==3
    frame = frame(:,:,3);
end
% If image is uint16, truncate it to uint8
if isa(frame,'uint16')
    frame = im2uint8(frame);
end
% Frequency cleanup of frame, horizontal 40 px frequency
freq = fftshift(fft2(frame));
freq(:,1:40:end) = 0;
frame = uint8(real(ifft2(fftshift(freq))));
threshold = graythresh(frame);
% Binarize frame
%frame = imbinarize(frame,threshold);
frames{1} = frame;
clear threshold frame freq path item

%% (B3) PIV: Configuration
fprintf('Module B3\n');
% Interrogation and search window size
sizeInt = 128;
sizeSrc = 64;
% Extension size: how many pixels to extend in each direction to extend
%                 an interrogation window to a search window
sizeExt = (sizeSrc-sizeInt)/2;
sizeFrame = size(frames{1});
% Number of windows
nWindow = sizeFrame/sizeInt;
% Calculate row and column delimiting index for each window
ticksRow = linspace(0,sizeFrame(1),nWindow(1)+1);
ticksCol = linspace(0,sizeFrame(2),nWindow(2)+1);
% Column cell, each cell contains a 1x2 matrix deliminiting that row
rangeRow = num2cell(vertcat((1+ticksRow(1:end-1)),ticksRow(2:end))',2);
% Row cell, each cell contains a 1x2 matrix deliminiting that column
rangeCol = num2cell(vertcat((1+ticksCol(1:end-1)),ticksCol(2:end))',2)';
% Ranges of each interrogation window
partInt = struct('row',repmat(rangeRow,1,nWindow(2)),...
                 'col',repmat(rangeCol,nWindow(1),1));
clear rangeCol rangeRow ticksCol ticksRow
% Ranges of each search window
partSrc = partInt;
if sizeExt > 0
    for i = 1:numel(partSrc)
        partSrc(i).row = partSrc(i).row + [-1 1]*sizeExt;
        partSrc(i).col = partSrc(i).col + [-1 1]*sizeExt;
    end
end
clear i
% Window partition struct
part = struct('int',partInt,'src',partSrc);
clear partSrc partInt

%% (B4) Forward difference PIV algorithm with real-time image loading
fprintf('Module B4\n');
% Start from the second frame and compare each frame with a previous one
% Directions:         j
%              +------->      ^
%              |            y |
%              |              |
%            i |              |      x
%              v              +------->
v = zeros([nWindow 2 length(frames)-1]);
MAX_FLUCTUATION = 1;
BOUNDARY = 2;
for k = 2:length(list)
    % Load the next image
    item = list(k);
    path = fullfile(item.folder,item.name);
    frame = imread(path);
    % If image is 3D, extract its blue channel
    if ndims(frame)==3
        frame = frame(:,:,3);
    end
    % If image is uint16, truncate it to uint8
    if isa(frame,'uint16')
        frame = im2uint8(frame);
    end
    FRAME_TYPE_FUNC = str2func(class(frame));
    % Frequency cleanup of frame, horizontal 40 px frequency
    %freq = fftshift(fft2(frame));
    %freq(:,1:40:end) = 0;
    %frame = uint8(ifft2(fftshift(freq)));
    temp = frame;
    line_x = 1:40:size(temp,2);
    line_x(line_x==1+size(temp,2)/2) = [];
    line_half_height = 2;
    freq = fftshift(fft2(temp));
    for line_k = line_x
        row_min = size(temp,1)/2+1-line_half_height;
        row_max = size(temp,1)/2+1+line_half_height;
        freq(row_min:row_max,line_k) = 0;
    end
    freq(1:size(temp,1)/2,size(temp,2)/2+1) = 0;
    freq(size(temp,1)/2+2:end,size(temp,2)/2+1) = 0;
    frame = FRAME_TYPE_FUNC(real(ifft2(fftshift(freq))));
    %threshold = graythresh(frame);
    % Binarize frame
    %frame = imbinarize(frame,threshold);
    frame = wiener2(frame,[5 5]);
    %frame = imbinarize(frame,'adaptive','Sensitivity',0);
    frame(mask) = 0;
    frames{2} = frame;
    % PIV search
    fprintf('B4: PIV Stencil: [%d] > %d\n',k-1,k);
    v(:,:,:,k-1) = fluidics.piv.high(frames{1},frames{2},nWindow,part);
    frames(1) = [];
end

%% (B5) Spurious vector removal and data treatment
% Obtain spurious vector locations in each frame
sp = fluidics.piv.isSpurious(v,2);
% Replace components of spurious vectors as NaN and fill missing values
spvc = repmat(permute(sp,[1 2 4 3]),[1 1 2 1]);
vr = v;
vr(spvc) = NaN;
vr = fillmissing(vr,'spline');
% Remove boundary layers
vr([1:2 end-1:end],:,:,:) = 0;
vr(:,[1:2 end-1:end],:,:) = 0;
% Outlier removal via Hampel identifier
for D = 1:2
    for i = 1:nWindow(1)
        for j = 1:nWindow(2)
            vr(i,j,D,:) = hampel(squeeze(vr(i,j,D,:)));
        end
    end
end

%% (B6) Save workspace
save(fullfile(DATA_PATH,'workspace'));