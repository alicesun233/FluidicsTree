classdef progress < handle
    properties
        Current
        Total
        Sticker
        Lines
        Reserved
        BarTip
    end
    
    methods
        function h = progress(i,k,s)
            h.Current = i;
            h.Total = k;
            h.Sticker = s;
            h.Lines = {};
            h.Reserved = 4;
            h.BarTip = '-\|/';
            h.draw();
        end
        
        function delete(h)
            
            fprintf('\n')
        end
        
        function update(h,i,s)
            h.Current = i;
            h.Sticker = s;
            h.draw();
        end
        
        function draw(h)
            if ~isempty(h.Lines)
                erasure = sum(cellfun(@length,h.Lines))+(length(h.Lines)-1);
                fprintf(repmat('\b',1,erasure))
            end
            
            ratio = max(0,min(1,h.Current/h.Total));
            percent = 100*ratio;
            
            cmdWndSize = get(0,'CommandWindowSize');
            cmdWndWidth = cmdWndSize(1);
            
            bar = repmat(' ',1,round(cmdWndWidth/2)-12-h.Reserved);
            if h.Current<h.Total
                bar(1:round(ratio*length(bar))) = '=';
                tip = h.BarTip(1+mod(h.Current-1,length(h.BarTip)));
                bar(find(bar=='=',1,'last')) = tip;
            else
                bar(:) = '=';
            end
            
            h.Lines = {sprintf('  % 7.2f%% [%s] %s (%d/%d)',...
                percent,bar,h.Sticker,h.Current,h.Total)};
            
            for k = 1:length(h.Lines)
                fprintf('%s',h.Lines{k})
                if k<length(h.Lines)
                    fprintf('\n')
                end
            end
        end
    end
end
