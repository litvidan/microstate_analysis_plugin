%ClearDataSortedByParent() Attempts to clear previous sorting information
%
% Usage:
%   >> AllEEG = ClearDataSortedByParent(AllEEG, Children, ClassIndex)
%
% Inputs:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "Children"
%   -> Name of the datasets in the AllEEG structure that should have the
%      sorting information cleared. If the dataset is not found, a warning
%      is issued.
%
%   "ClassIndex"
%   -> Array of numbers of microstate cluster sizes to be cleared (default = all)
%
% Output:
%
%   "AllEEG" 
%   -> AllEEG structure with all the updated EEGs


function AllEEG = ClearDataSortedByParent(AllEEG, Children, ClassIndex)
    
    if isempty(Children)
        return;
    end
    
    for c = 1:numel(Children)
        ToBeCleared = find(strcmp(Children{c},{AllEEG.setname}));
        if isempty(ToBeCleared)
            fprintf(1,'Could not find %s for clearing sorting information\n',Children{c});
        end
    
        for i = 1:numel(ToBeCleared)
            sIdx = ToBeCleared(i);
            if nargin < 3
                ClassIndex = AllEEG(sIdx).msinfo.ClustPar.MinClasses:AllEEG(sIdx).msinfo.ClustPar.MaxClasses;
            end
            for n = 1:numel(ClassIndex)
                for j = 1:ClassIndex(n)
                    AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).Labels{j} = sprintf('MS_%i.%i',ClassIndex(n),j);
                end
                AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).ColorMap = repmat([.75 .75 .75], ClassIndex(n), 1);
                AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).SortedBy = [];
                AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).SortMode = 'none';
            end
            disp(['MS sorting info cleared from ' AllEEG(sIdx).setname]);
            
            AllEEG(sIdx).saved = 'no';
            
            if isfield(AllEEG(sIdx).msinfo,'children')
                AllEEG = ClearDataSortedByParent(AllEEG,AllEEG(sIdx).msinfo.children);
            end
        end    
    end
end