# This is a prototype for plotting geotagged content on top of rayshader renderings

There are some experiments:
- main.R is just a sketch.
- lidar-test.R renders São Paulo lidar data as a point cloud using lidR.
- forest_heigth.R is currently the most advanced prototype. It collects canopy height data from ETH, a global data base of canopy height based on GEDI and Sentinel-2. It has a respolution of 10m, better than GEDI, and nice coverege. From canopy height, a lot o measurments can be derived, like carbon storage, for example.
  The file has listed all its packages dependencies.
  It loads ETH data, crop it based on Mekar Raya shapefile, rander as an elevation map in rayshader and plots labels and pictures accoring to their lat/long meta-data. Pictures were processes from .HEIC to .jpeg for performance and size.
  You can dowload ETH data using R but its slow, you should donwload directly from the ETH portal through the link:
  [https://www.research-collection.ethz.ch/handle/20.500.11850/609802](https://www.research-collection.ethz.ch/handle/20.500.11850/609802) 
  Than enter the cloud optimized geotiffs link.

The canopy_height.R script produces interactive 3D scenes and videos linke:


https://github.com/fmammoli/mekar/assets/1368669/aa04769b-d4ee-4e30-96eb-b5f534229287



https://github.com/fmammoli/mekar/assets/1368669/89f57e3f-1619-4681-b2e2-c033272c0aaa



https://github.com/fmammoli/mekar/assets/1368669/b300e1c8-e04d-482d-9e53-d21a7bc8130c

