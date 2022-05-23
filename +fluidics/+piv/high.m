function v = high(frame1,frame2,nWindow,part)
v = zeros([nWindow 2]);
sizeFrame = size(frame1);
for i = 1:nWindow(1)
    for j = 1:nWindow(2)
        % Extract interrogation window from the previous frame and search
        % window from the next frame, cropping when necessary
        intRows = part.int(i,j).row;
        intCols = part.int(i,j).col;
        srcRows = intRows;%min(sizeFrame(1),max(1,part.src(i,j).row));
        srcCols = intCols; %min(sizeFrame(2),max(1,part.src(i,j).col));
        wndPrev = frame1(intRows(1):intRows(2),intCols(1):intCols(2));
        wndNext = frame2(srcRows(1):srcRows(2),srcCols(1):srcCols(2));
        % Pad search window if necessary, U D L R
        padding = [max(0,1-part.src(i,j).row(1));
            max(0,part.src(i,j).row(end)-sizeFrame(1));
            max(0,1-part.src(i,j).col(1));
            max(0,part.src(i,j).col(end)-sizeFrame(2))];
        if any(padding~=0)
            wndNext = padarray(wndNext,[padding(1) padding(3)],'pre');
            wndNext = padarray(wndNext,[padding(2) padding(4)],'post');
        end

        move = fluidics.piv.pixelmove(wndPrev,wndNext);
        movement = fluidics.piv.subpixels(wndPrev,wndNext,move);
        v(i,j,1) = movement(2);
        v(i,j,2) = -movement(1);

%         % Perform cross-correlation and identify the peak index
%         xc = xcorr2(double(wndNext),double(wndPrev));
%         % Transform peak index into velocity
%         [peak,location] = max(xc(:));
%         if peak > 0
%             % Calculate peak sub index
%             [iPeak,jPeak] = ind2sub(size(xc),location);
%             % Calculate sub index of zero movement
%             iZero = ceil(size(xc,1)/2);
%             jZero = ceil(size(xc,2)/2);
%             % Convert (di,dj) to (vx,vy)=(dj,-di) through rotation
%             v(i,j,1) = jPeak - jZero;
%             v(i,j,2) = iZero - iPeak;
%         end
    end
end
