function [gnH] = canny(A, TH, TL)
    AG = imgaussfilt(A,1.4);
    [gx,gy] = imgradientxy(AG);
    alpha = atan(gy./gx);
    M = sqrt(gy.^2 +gx.^2);

    % dk
    gn = zeros(size(AG));
    dn = gn;
    for i = 1:size(AG,1)
        for j = 1:size(AG,2)
            deg = abs(rad2deg(alpha(i,j)));
            if deg<22.5 || (deg>=157.5 && deg<=180)
                dn(i,j)=1;
            elseif deg>=22.5 && deg<67.5
                dn(i,j)=2;
            elseif deg>=67.5 && deg<112.5
                dn(i,j)=3;
            elseif deg>=112.5 && deg<157.5
                dn(i,j)=4;
            end
        end
    end
m = size(A,1);
n = size(A,2);
    
    for i=1:m
        for j = 1:n
            if dn(i,j)==1 && M(i,j)>=max(M(max(i-1,1),j),M(min(i+1,m),j))
                gn(i,j)=M(i,j);
            elseif dn(i,j)==2 && M(i,j)>=max(M(max(i-1,1),max(j-1,1)),M(min(i+1,m),min(j+1,n)))
                gn(i,j)=M(i,j);
            elseif dn(i,j)==3 && M(i,j)>=max(M(i,max(j-1,1)),M(i,min(j+1,n)))
                gn(i,j)=M(i,j);
            elseif dn(i,j)==4 && M(i,j)>=max(M(max(i-1,1),min(j+1,n)),M(min(i+1,m),max(j-1,1)))
                gn(i,j)=M(i,j);
            else
                gn(i,j)=0;
            end
        end
    end

%     TH = 15000; %32000
%     TL = 7000; %18000
    gnH = gn>=TH;
    gnL = gn>=TL;
    gnL = gnL&~gnH;

    % Connect edges

    validedge = false(size(AG));
    for k = find(gnH)'
        [i,j] = ind2sub(size(AG),k);
        is = max(i-1,1):min(i+1,m);
        js = max(j-1,1):min(j+1,n);
        validedge(is,js) = validedge(is,js) | gnL(is,js);
    end
    gnL(~validedge) = false;
    gnH = gnH | gnL;
%     imshow(gnH)
end


