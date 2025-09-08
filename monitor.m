classdef monitor < handle

    properties
        Tag string =""%
        textLabel string = ""% 
        unit string = ""%
        parent % 
        siblings =[]%
        readFunc = @(x) NaN%function which takes the relevant instrument structure and outputs val of desired format
        setFunc = @(x) NaN%
        formatSpec = '%.2e'
        guiHand = struct %
        active = false %tag indicating if the monitor can be set (like a highvoltage power supply) or cant be set (like a pressure monitor)
        group string = ""%
        children = []%
    end
    properties (SetObservable) 
        lastRead %
        lock = false%
        monTimer = timer%
        parentListener
    end

    methods
        function obj = monitor(varargin)
            %assign all properties provided
            if (nargin > 0)
                props = varargin(1:2:numel(varargin));
                vals = varargin(2:2:numel(varargin));
                for i=1:numel(props)
                    obj.(props{i})=vals{i};
                end
            end
            
            %if ~strcmp(obj.parent.Type,"local")
            %obj.parentListener = listener(obj.parent(1),...
            %                    'lastRead','PostSet',@obj.read);
            %end
        end

        function val = read(obj) 
            % if all([obj.parent.Connected])
            try
                val = obj.readFunc(obj);
            catch
                val = nan;
            end
            obj.lastRead = val;
        end

        function set(obj,val)
            % if all([obj.parent.Connected])
            obj.setFunc(obj,val);
            % end
        end

        function guiSetCallback(obj,~,~)
            %DEFLBTNCALLBACK Sets Defl HVPS voltage based on user input
            % would like this to somehow remove this from the monitor class
            setVal = str2double(obj.guiHand.statusGrpSetField.String);
            %need to insert some error handling here
            obj.set(setVal);
            set(obj.guiHand.statusGrpSetField,'String','');
        end

        function setfield(obj,field,val)
            obj.(field) = val;
        end

        function printStr = sPrint(obj)
            printStr = sprintf('%s [%s]',obj.textLabel,obj.unit);
        end
    end
end