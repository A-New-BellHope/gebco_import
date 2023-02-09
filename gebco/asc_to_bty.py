#Joe Snider
#2/6/2023
#
# Convert data from gebco in the .asc format to .bty file for bellhop.
# Data can be downloaded from - https://download.gebco.net/
# Assumes an approximately flat earth.

import math
import geopy.distance

# Input file can be downloaded directly from the GEBCO website.
infil = open("gebco_2022_n33.7802_s32.3273_w-119.5189_e-116.992.asc", 'r')

# Output file for bellhop, and should match the .env file name.
outfil = open("san_diego.bty", 'w')

ncols = int(infil.readline().split()[1])
nrows = int(infil.readline().split()[1])
xllcorner = float(infil.readline().split()[1])
yllcorner = float(infil.readline().split()[1])
cellsize = float(infil.readline().split()[1])
NODATA_value = int(infil.readline().split()[1])

coords_1 = (yllcorner, xllcorner)
coords_2 = (yllcorner+cellsize, xllcorner)
grid_size = geopy.distance.geodesic(coords_1, coords_2).km

width = ncols*grid_size #km
height = nrows*grid_size #km

outfil.write("\'R\'\n")
outfil.write(str(ncols)+"\n")
for i in range(ncols):
    outfil.write(str( (-width/2.0 + i*grid_size) ) + " ")
outfil.write("\n")
outfil.write(str(nrows)+"\n")
for i in range(nrows):
    outfil.write(str( (-height/2.0 + i*grid_size) ) + " ")
outfil.write("\n")

out = ""
for i in range(nrows):
    line = infil.readline()
    depths = line.split()
    for j in range(ncols):
        depth = -1.0*float(depths[j])
        out += str(depth)+ " "
    out += "\n"
outfil.write(out)

infil.close()
outfil.close()

