function [data,FileName,PathName] = cmmFileParser(varargin)
    % [data,FileName,PathName]=CMMFILEPARSER(optional\path\to\file\here)
    % 
    % This is a simple function allows you to convert .xyz,.csv,.step, or .igs,
    % files to a three column (x,y,z) vector. Step and IGES files must be a
    % collection of points (typically from a CMM). This will not convert CAD
    % generated STEP and IGES files to x,y,z points.
    %
    %     Copyright (C) 2015  Devin C Prescott
    % 
    %     This program is free software: you can redistribute it and/or modify
    %     it under the terms of the GNU General Public License as published by
    %     the Free Software Foundation, either version 3 of the License, or
    %     (at your option) any later version.
    % 
    %     This program is distributed in the hope that it will be useful,
    %     but WITHOUT ANY WARRANTY; without even the implied warranty of
    %     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    %     GNU General Public License for more details.
    % 
    %     You should have received a copy of the GNU General Public License
    %     along with this program.  If not, see <http://www.gnu.org/licenses/>.
    %     
    %     Author:
    %     Devin C Prescott
    %     devin.c.prescott@gmail.com


    %% UI Open The Data File
    FilterSpec = {'*.xyz';'*.csv';'*.step';'*.stp';'*.igs';'*.iges';'*.txt'};
    FilterTypes = {'*.xyz;*.csv;*.step;*.stp;*.igs;*.iges;*.txt',...
        'CMM Files(*.xyz,*.csv,*.step,*.stp,*.igs,*.iges,*.txt)'};

    if nargin == 1
        [PathName,FileName,Ext] = fileparts(varargin{1});
        PathName = strcat(PathName,'\');
        FileName = strcat(FileName,Ext);
        ext = strcat('*',Ext);
        FilterIndex = find(strcmpi(FilterSpec,ext));
        if isempty(FilterIndex)
            msgbox('You specified an invalid file extension, try again.');
            return
        end
    else
        DialogTitle = 'Find Data File:';
            DeskTop =  winqueryreg(...
            'HKEY_CURRENT_USER',...
            'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders',...
            'Desktop');
        [FileNames,PathName,FilterIndex]=uigetfile(FilterTypes,DialogTitle,...
            DeskTop,'MultiSelect', 'on');
        if iscell(FileNames)
            data = [];
            for i = 1:length(FileNames);
                temp = dataParse(FileNames{i},PathName);
                data = [data;temp];
            end
            FileName = FileNames{end};
        elseif FileNames == 0
            data = [];
            return
        else
            data = dataParse(FileNames,PathName);
            FileName = FileNames;
        end
    end
end
%% Data Import
function data = dataParse(FileName,PathName)
    [~,~,Ext] = fileparts(FileName);
    % Figure out how to parse the data by file type
    switch Ext
        case {'.XYZ','.xyz'} % XYZ File - Skips header row and deletes columns 4 to 6
            data = dlmread(strcat(PathName,FileName),',',1,0);
            data(:,4:6)=[];
        case '.csv' % CSV File - Assume only columns are x,y,z with no headers
            data = csvread(strcat(PathName,FileName));
        case {'.stp','.step'} % Step File - Try to find CARTESIAN_POINT
            fid = fopen(strcat(PathName,FileName),'r');
            C = textscan(fid,'%s','delimiter',';');
            fclose(fid);
            pos = strfind(C{1,1}(:),'CARTESIAN_POINT');
            data = zeros(length(pos),3);
            for i = 1:length(pos)
                if isempty(pos{i}(:))
                    % Skip Empty cells
                else
                    str=C{1,1}{i,1};
                    str(str==' ') = '';
                    temp=regexp(str,'[-|,|(](\d+.\d+)','match');
                    for q = 1:3
                        data(i,q)=str2double(regexp(temp{q},...
                            '(\d+.\d+)|(-\d+.\d+)','match'));
                    end
                end
            end
        case {'.igs','.iges'} % IGES File - Find 116 Lines
            fid = fopen(strcat(PathName,FileName),'r');
            C = textscan(fid,'%s','delimiter','');
            fclose(fid);
            pos = strfind(C{1,1}(:),'116,');
            data = zeros(length(pos),3);
            for i = 1:length(pos)
                if isempty(pos{i}(:))
                    % Skip Empty cells
                else
                    str=C{1,1}{i,1};
                    str(str==' ') = '';
                    temp=regexp(str,'[-|,|(](\d+.\d+)','match');
                    for q = 1:3
                        data(i,q)=str2double(regexp(temp{q},...
                            '(\d+.\d+)|(-\d+.\d+)','match'));
                    end
                end
            end
        case {'.txt'} % Text file
            fid = fopen(strcat(PathName,FileName),'r');
            C = textscan(fid,'%s %f %f %f');
            fclose(fid);
            
            if strcmpi(C{1,1}(1),'scbada') % See if it's a Zeiss File
                pos = strfind(C{1,1}(:),'x');
                ind = cellfun(@isempty,pos);
                data = [C{1,2:4}];
                data(ind,:)=[];
            else % Try reading it just at XYZ columns
                try 
                    fid = fopen(strcat(PathName,FileName),'r');
                    C = textscan(fid,'%f %f %f');
                    fclose(fid);
                    data = [C{1,1:3}];
                catch % Give up
                    return
                end
            end

        otherwise
            disp('Unknown file type. You''re on your own.');
    end
    % Trim Rows containing all zeros
    data(sum(data==0,2)==3,:)=[];
end
