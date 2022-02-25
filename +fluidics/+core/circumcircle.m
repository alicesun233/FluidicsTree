function [c,r] = circumcircle(P)
switch size(P,1)
    case 0
        c = nan(1,2);
        r = nan;
    case 1
        c = P;
        r = 0;
    case 2
        c = mean(P,1);
        r = fluidics.core.rowdist(P)/2;
    case 3
        T = triangulation([1 2 3],P);
        [c,r] = T.circumcenter();
    otherwise
        error('Uncaught error')
end