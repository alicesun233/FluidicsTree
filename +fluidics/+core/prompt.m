function s = prompt(s,pOld,pNew)
updated = [];
% If input s(tring) is not empty, ask if user wants to update it
if ~isempty(s)
    while isempty(updated)
        % <OLD MESSAGE> <OLD CONTENT> [Y/N] <USER INPUT>
        myPrompt = sprintf('%s %s [Y/N] ',...
            fluidics.core.escape(pOld),...
            fluidics.core.escape(s));
        userInput = input(myPrompt,'s');
        if strcmpi('Y',userInput)
            updated = false;
        elseif strcmpi('N',userInput)
            updated = true;
            s = '';
        end
    end
end
% Now that s(tring) is empty or cleared, prompts user for update
if isempty(s)
    % <NEW MESSAGE>: <USER INPUT>
    myPrompt = sprintf('%s: ',fluidics.core.escape(pNew));
    userInput = input(myPrompt,'s');
    s = userInput;
end
