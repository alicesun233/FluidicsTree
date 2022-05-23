function ST = stationary(P,cutoff)

% Populate stationary particles using the first few frames
% This uses a clustering algorithm (linkage/cluster) and calculates
% from its results a centroid for each cluster
Pearly = vertcat(P{1:cutoff});
if isempty(Pearly)
    ST = struct('Points',{},'Lifespan',{});
    return
end
Z = linkage(Pearly);
T = cluster(Z,'cutoff',1,'Criterion','distance');

stationary = zeros(length(unique(T)),2);
lifespan = zeros(size(stationary,1),1);

% Compute cluster centroids
for i = fluidics.core.mat2row(unique(T))
    stationary(i,:) = mean(Pearly(T==i,:),1);
end

NS = size(stationary,1);
NF = length(P);

% Check the presence of any particle in any frame
cameo = false(NS,NF);
progress = fluidics.ui.progress(0,NF,'Initializing');
for k = 1:NF
    [idx,dist] = dsearchn(stationary,P{k});
    idx = idx(dist<1);
    cameo(unique(idx),k) = true;
    barLabel = sprintf('Frame #%d',k);
    progress.update(k,barLabel)
end
delete(progress)
% Update the presence and compute a duration
warning('off','stats:glmfit:PerfectSeparation')
warning('off','stats:glmfit:IterationLimit')
X = (1:NF)';
NameValuePairs = {'Distribution','binomial'};
progress = fluidics.ui.progress(0,NS,'Initializing');
for i = 1:NS
    Y = cameo(i,:)';
    cameoMdl = fitglm(X,Y,NameValuePairs{:});
    cameo(i,:) = predict(cameoMdl,X)';
    duration = find(cameo(i,:),1,'last');
    if isempty(duration)
        lifespan(i) = 0;
        continue
    end
    duration = find(cameo(1:duration),1,'last');
    if isempty(duration)
        lifespan(i) = 0;
        continue
    end
    lifespan(i) = duration;
    barLabel = sprintf('Particle #%d',i);
    progress.update(i,barLabel)
end
delete(progress)
warning('on','stats:glmfit:PerfectSeparation')
warning('on','stats:glmfit:IterationLimit')
% Structure the output
ST = struct(...
    'Points',fluidics.core.row2cell(stationary),...
    'Lifespan',num2cell(lifespan));
