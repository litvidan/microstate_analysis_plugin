
function [EEGout, success] = backfit_single_dataset(EEGin, template_source, template_EEG, n_classes, FitPar)
    % backfit_single_dataset - Apply microstate backfitting to a single EEG dataset.
    %
    % Inputs:
    %   EEGin           - EEG structure
    %   template_source - 'own' or name of another dataset
    %   template_EEG    - EEG structure with maps (if template_source ~= 'own')
    %   n_classes       - number of microstate classes
    %   FitPar          - parameters for AssignMStates
    %
    % Outputs:
    %   EEGout          - updated EEG structure
    %   success         - true if successful

    EEGout = EEGin;
    success = false;

    % 1. Obtain maps
    maps_are_valid = false;
    if strcmp(template_source, 'own')
        if isfield(EEGin, 'msinfo') && isstruct(EEGin.msinfo) && ...
           isfield(EEGin.msinfo, 'MSMaps') && ...
           numel(EEGin.msinfo.MSMaps) >= n_classes && ...
           ~isempty(EEGin.msinfo.MSMaps(n_classes).Maps)
            maps_are_valid = true;
            maps = EEGin.msinfo.MSMaps(n_classes).Maps;
            TemplateInfo.name = '<<собственные>>';
            TemplateInfo.SortedBy = EEGin.msinfo.MSMaps(n_classes).SortedBy;
            TemplateInfo.TemplateLabels = EEGin.msinfo.MSMaps(n_classes).Labels;
        end
    else
        if isfield(template_EEG, 'msinfo') && isstruct(template_EEG.msinfo) && ...
           isfield(template_EEG.msinfo, 'MSMaps') && ...
           numel(template_EEG.msinfo.MSMaps) >= n_classes && ...
           ~isempty(template_EEG.msinfo.MSMaps(n_classes).Maps)
            maps_are_valid = true;
            maps = template_EEG.msinfo.MSMaps(n_classes).Maps;
            TemplateInfo.name = template_source;
            TemplateInfo.SortedBy = template_EEG.msinfo.MSMaps(n_classes).SortedBy;
            TemplateInfo.TemplateLabels = template_EEG.msinfo.MSMaps(n_classes).Labels;
        end
    end

    if ~maps_are_valid
        warning('No valid maps for %d classes from source %s', n_classes, template_source);
        return;
    end

    % 2. Channel resampling if needed
    if ~strcmp(template_source, 'own') && EEGin.nbchan ~= template_EEG.nbchan
        [LocalToGlobal, ~] = MakeResampleMatrices(EEGin.chanlocs, template_EEG.chanlocs);
        EEGout.data = LocalToGlobal * reshape(EEGout.data, EEGout.nbchan, []);
        EEGout.nbchan = template_EEG.nbchan;
        EEGout.chanlocs = template_EEG.chanlocs;
    end

    % 3. Assign microstates and quantify dynamics
    [MSClass, gfp, IndGEVs] = AssignMStates(EEGout, maps, FitPar, true);
    if isempty(MSClass)
        warning('AssignMStates returned empty for %s', EEGin.setname);
        return;
    end

    MSStats = QuantifyMSDynamics(MSClass, gfp, EEGout.srate, TemplateInfo, IndGEVs);

    % 4. Store results
    if ~isfield(EEGout, 'msinfo') || ~isstruct(EEGout.msinfo)
        EEGout.msinfo = struct();
    end
    EEGout.msinfo.FitPar = FitPar;
    EEGout.msinfo.MSStats(n_classes) = MSStats;
    EEGout.saved = 'no';

    success = true;
end