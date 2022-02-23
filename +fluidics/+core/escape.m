function s = escape(s)
% Replace \ with \\
s = regexprep(s,'\\','\\\\');
% Replace % with %%
s = regexprep(s,'%','%%');
