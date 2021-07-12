% fit_Osprey.m
% Georg Oeltzschner, Johns Hopkins University 2019.
%
% USAGE:
% [fitParams] = fit_Osprey(dataToFit, resBasisSet, fitOpts);
% 
% DESCRIPTION:
% This is the function describing the Osprey fitting model, which is
% performed with the resampled basis set resBasisSet on the data contained
% in the FID-A data structure dataToFit, using the fit options in the
% structure fitOpts.
%
% This model is attempting to emulate the rather elusive original LCModel
% algorithm (Provencher, Magn Reson Med 30:672-679 (1993)).
% 
% OUTPUTS:
% fitParams   = Structure containing all necessary fit parameters
%                   - ampl: amplitudes for metabolite/MM/lipids
%                   - beta_j: amplitudes for baseline spline functions
%                   - lineshape: coefficients for lineshape convolution
%                   - ph0: zero-order phase correction
%                   - ph1: first-order phase correction
%                   - gaussLB: Gaussian dampening (common to all basis
%                       functions)
%                   - lorentzLB: Lorentzian dampening (individual to each
%                       basis function)
%                   - freqShift: frequency shift (individual to each basis
%                       function)
%
% INPUTS:
% dataToFit   = FID-A data structure
% basisSet    = FID-A basis set container
% fitOpts     = Structure containing fit options

function [fitParams, resBasisSet] = fit_Osprey(dataToFit, basisSet, fitOpts)

%%% 0. PREPARE DATA AND BASIS SET %%%
try
    figHandles = findall(groot, 'Type', 'Figure', 'Name', 'Osprey' );
    progressText = figHandles.Children.Children(1).Children(4).Children.Children;
catch
   progressText = [];
end


dataToFit               = op_zeropad(dataToFit, 2);
% Resample basis set to match data resolution and frequency range
resBasisSet             = fit_resampleBasis(dataToFit, basisSet);


%%% 1. EXTRACT OPTIONS AND PREPARE FIT %%%
% Extract ppm fit range
fitRangePPM             = fitOpts.range;
% Initialize the baseline spline parameters
minKnotSpacingPPM       = fitOpts.bLineKnotSpace; % this is the DKNTMN parameter in LCModel


%%% 2. INITIAL REFERENCING %%%
% Determine initial coarse frequency shift from cross-correlation with
% landmark delta functions for NAA, Cr, Cho.
if ~isfield(dataToFit,'refShift') %NO referenceing so far
    fprintf('\nRunning initial referencing...');
    if ~isempty(progressText) 
        String = get(progressText,'String');
            set(progressText,'String' ,sprintf([String(1,:) '\nRunning initial referencing...\n']));
        drawnow
    end
    [refShift, refFWHM] = fit_OspreyReferencing(dataToFit);
    % Apply initial referencing shift
    dataToFitRef = op_freqshift(dataToFit, -refShift);
else %Referencing was performed on another Subspec or the center voxel (MRSI)
    fprintf('\nInitial was performed on another Subspec or the center voxel (MRSI)...');
    if ~isempty(progressText) 
        String = get(progressText,'String');
        set(progressText,'String' ,sprintf([String(1,:) '\nInitial was performed on another Subspec or the center voxel (MRSI)...\n']));
        drawnow
    end    
    refShift = dataToFit.refShift;
    refFWHM = dataToFit.refFWHM;
    % Apply initial referencing shift
    dataToFitRef = op_freqshift(dataToFit, -refShift);
end

%%% 3. PRELIMINARY ANALYSIS STEP 1 %%%
% In step 1 of the preliminary analysis, a reduced basis set (Cr, Glu, Ins,
% GPC, NAA) is used to obtain a first estimate for the frequency shift
% and the zero- and first-order phase shift parameters.
% Well-phased spectra should be fine with the starting values for the phase
% corrections, which are zero degrees (zero order) and zero degrees/ppm
% (first order).
%
% The preliminary analysis performed by LCModel allows to cycle those
% starting values, i.e. do the preliminary analysis with pairs of e.g. [30,
% 30] etc. - this is governed by the choice of the DEGZER/SDDEGZ and
% DEGPPM/SDDEGP parameters.
%
% In that case, the preliminary analysis is run multiple times, and the
% best phasing / referencing shift parameters are chosen.
% (Worth exploring in future versions by passing the starting values for
% the phase corrections as arguments.)
if ~isfield(fitOpts, 'MRSIpriors')
    fprintf('\nRunning preliminary analysis with reduced basis set...');
    if ~isempty(progressText) 
        String = get(progressText,'String');
        set(progressText,'String' ,sprintf([String(1,:)  '\nRunning preliminary analysis with reduced basis set...\n']));
        drawnow
    end
    [fitParamsStep1] = fit_Osprey_PrelimReduced(dataToFitRef, resBasisSet, fitRangePPM);
else
    fprintf('\nTake priors from center voxel...');
    if ~isempty(progressText) 
        String = get(progressText,'String');
        set(progressText,'String' ,sprintf([String(1,:)  '\nTake priors from center voxel...\n']));
        drawnow
    end
    fitParamsStep1 = fitOpts.MRSIpriors.prelimParams; % Get results from center voxel
    %Overwrite parameters with final results, not sure if this is better
    %then the inital results
    fitParamsStep1.ph0 = fitOpts.MRSIpriors.ph0;
    fitParamsStep1.ph1 = fitOpts.MRSIpriors.ph1;
    fitParamsStep1.gaussLB = fitOpts.MRSIpriors.gaussLB;
    
end


%%% 4. FINAL PRELIMINARY ANALYSIS STEP 2 %%%
% In the final step of the preliminary analysis, the full basis set is used
% with the full LCModel (except for baseline regularization) to obtain
% the final optimal starting values.
fprintf('\nRunning final preliminary analysis step with full basis set...\n');
if ~isempty(progressText) 
    String = get(progressText,'String');
    set(progressText,'String' ,sprintf([String(1,:)  '\nRunning final preliminary analysis step with full basis set...\n']));
    drawnow
end

if isfield(fitOpts,'coMM3') && isfield(dataToFit,'refShift') && ~isfield(fitOpts,'Diff2')
    switch fitOpts.coMM3        
        case '3to2MMsoft'
        [fitParamsStep2] = fit_OspreyPrelimStep2coMM3(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM,0.66,'MM');
        case '1to1GABAsoft'
        [fitParamsStep2] = fit_OspreyPrelimStep2coMM3(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM,1,'GABA');
        case '3to2GABAsoft'  % 3:2 GABA and co-edited MM3 model
        [fitParamsStep2] = fit_OspreyPrelimStep2coMM3(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM,0.66,'GABA');
        case '2to3GABAsoft' % 2:3 GABA and co-edited MM3 model
        [fitParamsStep2] = fit_OspreyPrelimStep2coMM3(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM,1.5,'GABA');
        case 'freeGauss' % Gauss with free frequency and linewidth
        [fitParamsStep2] = fit_OspreyPrelimStep2freeGauss(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM);
        resBasisSet = fitParamsStep2.resBasisSetUpdated;
        otherwise
            [fitParamsStep2] = fit_OspreyPrelimStep2(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM);
    end             
else
    [fitParamsStep2] = fit_OspreyPrelimStep2(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM, fitParamsStep1, refFWHM);    
end

% [J,~,CRLB] = fit_Osprey_CRLB(dataToFitRef, resBasisSet, minKnotSpacingPPM, fitRangePPM,fitParamsStep2,refShift);

%%% 5. CREATE OUTPUT %%%
% Return fit parameters
fitParams = fitParamsStep2;
fitParams.refShift = refShift;
fitParams.refFWHM = refFWHM;
fitParams.prelimParams = fitParamsStep1;
%fitParams.CRLB = CRLB;
end





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
