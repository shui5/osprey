%% jobTwix.m
%   This function describes an Osprey job defined in a MATLAB script.
%
%   A valid Osprey job contains four distinct classes of items:
%       1. basic information on the MRS sequence used
%       2. several settings for data handling and modeling
%       3. a list of MRS (and, optionally, structural imaging) data files 
%          to be loaded
%       4. an output folder to store the results and exported files
%
%   The list of MRS and structural imaging files is provided in the form of
%   cell arrays. They can simply be provided explicitly, or from a more
%   complex script that automatically determines file names from a given
%   folder structure.
%
%   Osprey distinguishes between four sets of data:
%       - metabolite (water-suppressed) data
%           (MANDATORY)
%           Defined in cell array "files"
%       - water reference data acquired with the SAME sequence as the
%           metabolite data, just without water suppression RF pulses. This
%           data is used to determine complex coil combination
%           coefficients, and perform eddy current correction.
%           (OPTIONAL)
%           Defined in cell array "files_ref"
%       - additional water data used for water-scaled quantification,
%           usually from short-TE acquisitions due to reduced T2-weighting
%           (OPTIONAL)
%           Defined in cell array "files_w"
%       - Structural image data used for co-registration and tissue class
%           segmentation (usually a T1 MPRAGE). These files need to be
%           provided in the NIfTI format (*.nii) or, for GE data, as a 
%           folder containing DICOM Files (*.dcm).
%           (OPTIONAL)
%           Defined in cell array "files_nii"
%
%   Files in the formats
%       - .7 (GE)
%       - .SDAT, .DATA/.LIST, .RAW/.SIN/.LAB (Philips)
%       - .DAT (Siemens)
%   usually contain all of the acquired data in a single file per scan. GE
%   systems store water reference data in the same .7 file, so there is no
%   need to specify it separately under files_ref.
%
%   Files in the formats
%       - .DCM (any)
%       - .IMA, .RDA (Siemens)
%   may contain separate files for each average. Instead of providing
%   individual file names, please specify folders. Metabolite data, water
%   reference data, and water data need to be located in separate folders.
%
%   In the example script at hand the MATLAB functions strrep and which are
%   used to generate a relative path, which allows you to run the examples
%   on your machine directly. To set up your own Osprey job supply the
%   specific locations as described above.
%
%   AUTHOR:
%       Dr. Georg Oeltzschner (Johns Hopkins University, 2019-07-15)
%       goeltzs1@jhmi.edu
%   
%   HISTORY:
%       2019-07-15: First version of the code.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 1. SPECIFY SEQUENCE INFORMATION %%%

% Specify sequence type
seqType = 'unedited';           % OPTIONS:    - 'unedited' (default)
                                %             - 'MEGA'
                                %             - 'HERMES'
                                %             - 'HERCULES'

% Specify editing targets
editTarget = {'none'};            % OPTIONS:    - {'none'} (default if 'unedited')
                                %             - {'GABA'}, {'GSH'}  (for 'MEGA')
                                %             - {'GABA, 'GSH}, {'GABA, GSH, EtOH'} (for 'HERMES')
                                %             - {'HERCULES1'}, {'HERCULES2'} (for 'HERCULES')
                               
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 2. SPECIFY DATA HANDLING AND MODELING OPTIONS %%%
% Which spectral registration method should be used? Robust spectral
% registration is default, a frequency restricted spectral registration
% method is also availaible and is linked to the fit range. 
opts.SpecReg = 'RobSpecReg';                  % OPTIONS:    - 'RobSpecReg' (default)
                                              %             - 'RestrSpecReg'
                                              %             - 'none'

% Save LCModel-exportable files for each spectrum?
opts.saveLCM                = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)
                                                
% Save jMRUI-exportable files for each spectrum?
opts.saveJMRUI              = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)
                                                                                                
% Save processed spectra in vendor-specific format (SDAT/SPAR, RDA, P)?
opts.saveVendor             = 1;                % OPTIONS:    - 0 (no, default)
                                                %             - 1 (yes)

% Select the metabolites to be included in the basis set as a cell array,
% with entries separates by commas.
% With default Osprey basis sets, you can select the following metabolites:
% Ala, Asc, Asp, bHB, bHG, Cit, Cr, CrCH2, EtOH, GABA, GPC, GSH, Glc, Gln,
% Glu, Gly, H2O, Ins, Lac, NAA, NAAG, PCh, PCr, PE, Phenyl, Scyllo, Ser,
% Tau, Tyros, MM09, MM12, MM14, MM17, MM20, Lip09, Lip13, Lip20.
% If you enter 'default', the basis set will include all of the above
% except for Ala, bHB, bHG, Cit, EtOH, Glc, Gly, Phenyl, Ser, and Tyros.
opts.fit.includeMetabs      = {'default'};      % OPTIONS:    - {'default'}
                                                %             - {'full'}
                                                %             - {custom} 
                                                
% Choose the fitting algorithm
opts.fit.method             = 'Osprey';       % OPTIONS:  - 'Osprey' (default)
                                                %           - 'AQSES' (planned)
                                                %           - 'TARQUIN' (planned)

% Choose the fitting style for difference-edited datasets (MEGA, HERMES, HERCULES)
% (only available for the Osprey fitting method)
opts.fit.style              = 'Separate';   % OPTIONS:  - 'Concatenated' (default) - will fit DIFF and SUM simultaneously)
                                                %           - 'Separate' - will fit DIFF and OFF separately

% Determine fitting range (in ppm) for the metabolite and water spectra
opts.fit.range              = [0.2 4.2];        % [ppm] Default: [0.2 4.2]
opts.fit.rangeWater         = [2.0 7.4];        % [ppm] Default: [2.0 7.4]

% Determine the baseline knot spacing (in ppm) for the metabolite spectra
opts.fit.bLineKnotSpace     = 0.4;              % [ppm] Default: 0.4.

% Add macromolecule and lipid basis functions to the fit? 
opts.fit.fitMM              = 1;                % OPTIONS:    - 0 (no)
                                                %             - 1 (yes, default)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 3. SPECIFY MRS DATA AND STRUCTURAL IMAGING FILES %%
% When using single-average Siemens RDA or DICOM files, specify their
% folders instead of single files!

% Specify metabolite data
% (MANDATORY)
files       = {which('exampledata/twix/sub-01/mrs/sub-01_press/sub-01_PRESS30.dat'),...
               which('exampledata/twix/sub-02/mrs/sub-02_press/sub-02_PRESS30.dat')};

% Specify water reference data for eddy-current correction (same sequence as metabolite data!)
% (OPTIONAL)
% Leave empty for GE P-files (.7) - these include water reference data by
% default.
files_ref   = {which('exampledata/twix/sub-01/mrs/sub-01_press-water/sub-01_PRESS30_w.dat'),...
               which('exampledata/twix/sub-02/mrs/sub-02_press-water/sub-02_PRESS30_w.dat')};

% Specify water data for quantification (e.g. short-TE water scan)
% (OPTIONAL)
files_w     = {};

% Specify metabolite-nulled data for quantification
% (OPTIONAL)
files_mm     = {};           

% Specify T1-weighted structural imaging data
% (OPTIONAL)
% Link to single NIfTI (*.nii) files for Siemens and Philips data
% Link to DICOM (*.dcm) folders for GE data
files_nii   = {which('exampledata/twix/sub-01/anat/sub-01_T1w.nii.gz'),...
               which('exampledata/twix/sub-02/anat/sub-02_T1w.nii.gz')};

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% 4. SPECIFY OUTPUT FOLDER %%
% The Osprey data container will be saved as a *.mat file in the output
% folder that you specify below. In addition, any exported files (for use
% with jMRUI, TARQUIN, or LCModel) will be saved in sub-folders.

% Specify output folder
% (MANDATORY)
outputFolder = strrep(which('exampledata/twix/jobTwix.m'),'jobTwix.m','derivatives');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%