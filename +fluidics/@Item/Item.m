classdef Item < handle
    properties
        Value = []
        Frame = NaN
    end
    methods
        function obj = Item(varargin)
            if nargin==2
                obj.Value = varargin{1};
                obj.Frame = varargin{2};
            elseif nargin~=0
                throw('Error while invoking the constructor')
            end
        end
    end
end