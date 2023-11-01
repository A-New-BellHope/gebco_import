% Joe Snider, 10/31/2023
% Convert data from GEBCO and HYCOM to bellhop format.
% Semi-automated - specify the filenames of the raw data downloaded from
% the GEBCO and HYCOM webapps. See README.md for more details.
%
% Note - Requires the Mapping Toolbox

%% Download these two files from the web

% gebco data from https://download.gebco.net/
GEBCO_FILE_NAME = 'gebco_2022_n33.7802_s32.3273_w-119.5189_e-116.992.asc';

% hycom data from the matching lat/long (you can type them in) at your
% desired time. Probably from 
% https://ncss.hycom.org/thredds/ncss/grid/GLBy0.08/expt_93.0/ts3z/dataset.html
% But, there are other models, e.g., expt_90.9. See hycom.org
HYCOM_FILE_NAME = 'expt_93_ts3z.nc4';

% save files - must have the same start for bellhop.
BATHYMETRY_FILE_NAME = "test.bty";
SSP_FILE_NAME = "test.ssp";

% can use whatever ellipsoid, but this units should be km for bellhop.
WORLD_ELLIPSOID_MODEL = wgs84Ellipsoid("km");

% NB - The 'standard' bellhop MATLAB files shadow the distance function
%      from the Mapping Toolbox and cause major issues. MATLAB doesn't
%      have a good way to override function order preferences, so just
%      warn and quit.

check_distance = which('distance');
if (~contains(check_distance, "toolbox\map"))
    error("The Mapping Toolbox distance function is not available. " + ...
        "Check that the Mapping Toolbox is installed." + ...
        "Note that the BELLHOP plotting library conflicts and should not" + ...
        " be added to the path.");
end

%% parse the gebco data to create a bathymetry and set the units
gebcoFile = fopen(GEBCO_FILE_NAME, 'r');

ncols = textscan(gebcoFile, "%s %d", 1);
nrows = textscan(gebcoFile, "%s %d", 1);
xllcorner = textscan(gebcoFile, "%s %f", 1);
yllcorner = textscan(gebcoFile, "%s %f", 1);
cellsize = textscan(gebcoFile, "%s %f", 1);
NODATA = textscan(gebcoFile, "%s %d", 1);

bathymetryOutputFile = fopen(BATHYMETRY_FILE_NAME, 'w');
fprintf(bathymetryOutputFile, "\'R\'\n");
fprintf(bathymetryOutputFile, "%d\n", ncols{2});
for i = 1:ncols{2}
    d = distance(yllcorner{2}, xllcorner{2}, ...
        yllcorner{2}, xllcorner{2} + double(i-1) * cellsize{2}, ...
        WORLD_ELLIPSOID_MODEL);
    fprintf(bathymetryOutputFile, "%f ", d);
end
fprintf(bathymetryOutputFile,"\n%d\n", nrows{2});
for i = 1:nrows{2}
    d = distance(yllcorner{2}, xllcorner{2}, ...
        yllcorner{2} + double(i-1) * cellsize{2}, xllcorner{2}, ...
        WORLD_ELLIPSOID_MODEL);
    fprintf(bathymetryOutputFile, "%f ", d);
end
fprintf(bathymetryOutputFile, "\n");
for i=1:nrows{2}
    %probably faster to read the whole matrix
    d = textscan(gebcoFile, "%f", ncols{2});
    d = -1*d{1};
    fprintf(bathymetryOutputFile, "%f ", d);
    fprintf(bathymetryOutputFile,"\n");
end
fclose(bathymetryOutputFile);
fclose(gebcoFile);

%% load HYCOM data
salinitytemp = ncread(HYCOM_FILE_NAME,'salinity');% Salinity
lon = ncread(HYCOM_FILE_NAME,'lon');
lat = ncread(HYCOM_FILE_NAME,'lat');
watertemp = ncread(HYCOM_FILE_NAME,'water_temp');% temperature NA3
hhycom = ncread(HYCOM_FILE_NAME,'depth');

%add the depth 12000m where all the values will be equal to values at 5000m
% TODO: speed at 12km should be some known value, but this is what Tiago did
hhycom(end+1)=12000;
salinitytemp(:,:,end+1) = salinitytemp(:,:,end);
watertemp(:,:,end+1) = watertemp(:,:,end);

%reshaping water depth vector (from to hhycom h)
CR7 = reshape(hhycom,1,1,length(hhycom));
h = repmat(CR7,size(salinitytemp,1),size(salinitytemp,2));
speed1 = sndspd(salinitytemp,watertemp,h);

% TODO: Bellhop does some spline stuff and interpolating could have
% unphysical problems, like projected sound speed on land influencing the 
% value in the water column. This seems to be an open problem.

%interpolate regions on land for smoothing in bellhop
speed = fillmissing(speed1,'linear',2,'EndValues','nearest');
speed = fillmissing(speed,'nearest');

%any heights that have a nan are under the bottom.
% Use nearest above in each depth as recommended.
% TODO: should be vectorizable if this is slow.
for i=1:size(speed,1)
    for j=1:size(speed, 2)
        q = fillmissing(squeeze(speed(i, j, :)), 'nearest');
        for k=1:size(speed, 3)
            speed(i, j, k) = q(k);
        end
    end
end

%% convert to distance coordinates that line up with the bathymetry
xPosition = lon;
yPosition = lat;
for i=1:length(lon)
    xPosition(i) = distance(yllcorner{2}, xllcorner{2}, ...
        lat(1), lon(i), ...
        WORLD_ELLIPSOID_MODEL);
end
for i=1:length(lat)
    yPosition(i) = distance(yllcorner{2}, xllcorner{2}, ...
        lat(i), lon(1), ...
        WORLD_ELLIPSOID_MODEL);
end

%% dump as lats, longs, depths, data in same rows as .ssp
sspFile = fopen(SSP_FILE_NAME, 'w');
fprintf(sspFile, '%d\n', length(xPosition));
fprintf(sspFile, '%g ', xPosition);
fprintf(sspFile, '\n');
fprintf(sspFile, '%d\n', length(yPosition));
fprintf(sspFile, '%g ', yPosition);
fprintf(sspFile, '\n');
fprintf(sspFile, '%d\n', length(hhycom));
fprintf(sspFile, '%g ', hhycom);
fprintf(sspFile, '\n');
for i=1:length(hhycom)
    for j=1:length(lat)
        fprintf(sspFile, '%g ', squeeze(speed(:, j, i)));
        fprintf(sspFile, '\n');
    end
end
fclose(sspFile);


