function [c,r] = mincirc(P)
%https://link.springer.com/content/pdf/10.1007%2FBFb0038202.pdf
[c,r] = b_mincirc(P,[]);
end

function [c,r] = b_mincirc(P,R)
if size(P,1)==0||size(R,1)==3
    [c,r] = fluidics.core.circumcircle(R);
else
    i = randi(size(P,1));
    p = P(i,:);
    P(i,:) = [];
    [c,r] = b_mincirc(P,R);
    if isnan(r)||fluidics.core.dist(p,c)>r
        [c,r] = b_mincirc(P,vertcat(R,p));
    end
end
end