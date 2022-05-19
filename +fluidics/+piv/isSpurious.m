% ISSPURIOUS Magic spurious marking function
%   M = ISSPURIOUS(V,T) accepts a velocity field V of size MxNxDxK and
%   returns a boolean matrix of size MxNxK. If an entry in M is marked
%   true, then that entry is spurious. The threshold is T.
function M = isSpurious(V,T)
% Initialize output boolean matrix
sV = size(V);
% Use normres for each frame
M = false(sV([1 2 4]));
for k = 1:size(V,4)
    M(:,:,k) = normres(V(:,:,:,k),T);
end
end

function Mk = normres(Vk,T)
% Neighborhood radius (square)
R = 1;
% Center index when reshaped as a column
Ic = (2*R+1)*R+(R+1);
% Zero-pad Vk in both spatial directions
Vkp = padarray(Vk,[R R 0],'both');
% Fluctuation
Fl = zeros(size(Vk));
% estimated measurement noise level (in pixel units)
eps = 0.5;
% Loop through dimensions
for D = 1:size(Vk,3)
    % Loop through all pixels in non-padded Vk
    for I = 1:size(Vk,1)
        for J = 1:size(Vk,2)
            % The R x R surrounding neighborhood
            Vn = Vkp(I:I+2*R,J:J+2*R,D);
            Vn = Vn(:);
            Vc = Vn(Ic);
            Vn(Ic) = [];
            % The median of the neighborhood
            med = median(Vn);
            % The center fluctuation w.r.t. the median
            Flc = abs(Vc-med);
            % The surrounding neighborhood fluctuation w.r.t the median
            Fln = median(abs(Vn-med));
            Fl(I,J,D) = abs(Flc/(Fln+eps));
        end
    end
end
% Use the norm of fluctuation to mark cells
Mk = vecnorm(Fl,2,3)>T;
end