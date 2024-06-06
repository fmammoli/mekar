# Setting sys to english
Sys.setenv(LANG = "en")

#Installing and loading libs
libs <- c(
  "tidyverse", "sf", "geodata", "exifr", "magick", "av",
  "terra", "classInt", "rayshader", "rayvertex"
)

installed_libs <- libs %in% rownames(
  installed.packages()
)

if(any(installed_libs == FALSE)) {
  install.packages(libs[!installed_libs])
}

lapply(
  libs,
  library,
  character.only = TRUE
)

#donwload ETH files for canopy hight

base_url <- "https://libdrive.ethz.ch/index.php/s/cO8or7iOe5dT2Rt/download?path=%2F3deg_cogs&files="

files <- c(
  "ETH_GlobalCanopyHeight_10m_2020_N00E108_Map.tif",
  "ETH_GlobalCanopyHeight_10m_2020_N00E111_Map.tif",
  "ETH_GlobalCanopyHeight_10m_2020_S03E108_Map.tif",
  "ETH_GlobalCanopyHeight_10m_2020_S03E111_Map.tif"
)

eth_folder <- file.path(getwd(), "ETH_canopy_height")

#you have to uncomment this to donwload, but you can also download directly from the website
# for(file in files) {
#   url <- paste0(base_url, file)
#   download.file(
#     url,
#     destfile = file.path(eth_folder, basename(url)),
#     mode = "wb"
#   )
# }

# Filtering ETH data to load only what intersects with Mekar Raya Shapefile
raster_files <- list.files(
  path = eth_folder,
  pattern = "ETH",
  full.names = TRUE
)
print(raster_files)

mekar_folder <- file.path(getwd(), "Mekar Raya GIS Data/")
aoi_borders <- sf::st_read(mekar_folder) |> sf::st_as_sf()

nama_sf <- aoi_borders |>
  group_by(NAMA) |>
  summarise() |>
  as.data.frame() |>
  unique() |>
  st_as_sf() |>
  st_transform(crs = st_crs(4326))

nama_sf

ggplot2::ggplot(aoi_borders) +
  ggplot2::geom_sf(fill = "white") +
  geom_sf_text(data= nama_sf, aes(label = NAMA, size = 2.5, hjust = 1))

#filter the raws where NAMA not euqal to Sungai Keramat Tanikng
#the union is interesting to get the outside borders.
aoi_sf <- aoi_borders |>
  # dplyr::filter(
  #   !NAMA %in% c("Sungai Keramat Tanikng")
  # ) |>
  sf::st_union() |>
  st_transform(crs = st_crs(4326))
aoi_sf

ggplot2::ggplot(aoi_sf) +
  ggplot2::geom_sf() +
  ggplot2::geom_sf_text(data = nama_sf, aes(label = NAMA))

aoi_vect <- terra::vect(aoi_sf)

forest_height_list <- lapply(
  raster_files,
  terra::rast
)

forest_height_list

forest_height_raster_list <- lapply(
  forest_height_list,
  function(x) {
    aoi_inter <- terra::intersect(
      aoi_vect,
      terra::ext(x)
    )
    length(aoi_inter) |> print()
    if(length(terra::geom(aoi_inter)) > 0) {
      crop <- terra::crop(
        x,
        aoi_vect,
        snap = "in",
        mask = TRUE
      )
      return(crop)
    }
  }
) |>
  purrr::discard(is.null)

forest_height_raster_list
if(length(forest_height_raster_list) > 1) {
  forest_height_mosaic <- do.call(
    terra::mosaic,
    forest_height_raster
  )
} else {
  forest_height_mekar <- forest_height_raster_list[[1]] |>
    terra::disagg(fact = 2, method = "near")
}
forest_height_mekar
forest_height_mekar_df <- forest_height_mekar |>
  as.data.frame(xy = TRUE)
head(forest_height_mekar_df)
names(forest_height_mekar_df)[3] <- "height"



# Breaks
breaks <- classInt::classIntervals(
  forest_height_mekar_df$height,
  n = 5,
  style = "quantile",
)$brks

# colors
cols <- c(
  "#f9da9b", "#6daa55", "#205544"
)

texture <- colorRampPalette(
  cols,
  bias = 1
)(8)

# Plotting
p <- ggplot(forest_height_mekar_df) +
  geom_raster(
    aes(
      x = x,
      y = y,
      fill = height
    )
  ) +
  ggplot2::scale_fill_gradientn(
    name = "height (m)",
    colors = texture,
    breaks = breaks
  ) +
  ggplot2::coord_sf(crs = 4326) +
  ggplot2::guides(
    fill = guide_legend(
      direction = "vertical",
      keyheight = unit(5, "mm"),
      keywidth = unit(5, "mm"),
      title.position = "top",
      label.position = "right",
      title.hjust = .5,
      label.hjust = .5,
      ncol = 1,
      byrow = FALSE
    )
  ) +
  ggplot2::theme_minimal() +
  #this are details for the theme that are not working...
  theme(
    axis.line = element_blank(),
    legend.position = "right",
    legend.title = element_text(
      size = 11,
      color = "grey10"
    ),
    legend.text = element_text(
      size = 10,
      color = "grey10"
    ),
    panel.grid.major = element_line(
      color = "white"
    ),
    panel.grid.minor = element_line(
      color = "white"
    ),
    plot.background = element_rect(
      fill = "white", color = NA
    ),
    legend.background = element_rect(
      fill = "white", color = NA
    ),
    panel.border = element_rect(
      color = "white", fill = NA
    ),
    plot.margin = unit(
      c(
        t = 0,
        r = 0,
        b = 0,
        l = 0
      ), "lines"
    ),
    axis.title.x = element_blank(),
    axis.title.y = element_blank(),
    axis.text.x = element_blank(),
    axis.text.y = element_blank()
  ) +
  geom_sf(
    data = st_transform(aoi_borders, crs = st_crs(4326)),
    fill = NA, linewidth = 1.5, color = "#9234a5"
  )

p

# Render Rayshader

h <- nrow(forest_height_mekar)
w <- ncol(forest_height_mekar)

phm <- rayshader::plot_gg(
  ggobj = p,
  width = w / 300,
  height = h / 300,
  scale = 150,
  solid = FALSE,
  soliddepth = 0,
  shadow = TRUE,
  shadow_intensity = .4,
  offset_edges = FALSE,
  sunangle = 300,
  windowsize = c(1200, 800),
  phi = 25,
  theta = 45,
  zoom = .5,
  multicore = TRUE,
  background = "white",
  save_height_matrix = TRUE
)

rayshader::render_camera(
  phi = 25,
  zoom = .3,
  theta = 45
)

#TODO
#render the shapefile using rayshader::render_multipolygonz()

# Rendering text labels
df <- nama_sf |> as.data.frame()
df$mean <- st_geometry(nama_sf) |> st_centroid()

apply(df |> as.data.frame(), 1, function(item) {
  coords <- st_coordinates(item$mean)
  render_label(phm, extent = st_bbox(nama_sf), long = coords[,"X"], lat = coords[,"Y"], z = 5000, zscale = 10,  textcolor = "gray20", linecolor = "gray20",
             text = item["NAMA"], relativez = FALSE, textsize = 1, linewidth = 3)

})

# Rendering pictures on top of 3d canopy height
gps_tags <- c(
  "GPSLatitude",
  "GPSLongitude",
  "GPSDateTime",
  "GPSAltitude",
  "GPSPosititon",
  "GPSImageDirection",
  "GPSTimeStamp",
  "GPSDateStamp",
  "GPSSpeed",
  "GPSHPositioningError"
)

# Pick pictures, one for each day just for testing placement, picking the 10th pic of each day
files_1 <- list.files(file.path(getwd(), "20240501"), full.names = TRUE, pattern = "*.HEIC") |>
  exifr::read_exif(tags = gps_tags)
files_2 <- list.files(file.path(getwd(), "20240502"), full.names = TRUE, pattern = "*.HEIC") |>
  exifr::read_exif(tags = gps_tags)

pic_df <- data.frame(
  source_file = c(files_1$SourceFile[10],files_2$SourceFile[10]),
  long = c(files_1$GPSLongitude[10], files_2$GPSLongitude[10]),
  lat = c(files_1$GPSLatitude[10], files_2$GPSLatitude[10])
)
pic_df

picture_output_folder <- file.path(getwd(), "low_res_pictures")

#converting .HEIC images into lighter jpeg ones
imgs <- pic_df |> apply(1, function(row) {
  magick::image_read(row["source_file"]) |>
    magick::image_write(
      path = file.path(picture_output_folder, paste0(basename(row["source_file"]), ".jpg")),
      format = "jpg",
      quality = 50)
})

pic_df$low_res_img <- imgs
pic_df
#create meshes for each image, is this the best way though? probably not
#and then render the mesh to tho rgl device
pic_df |>
  st_as_sf(coords = c("long", "lat")) |>
  apply(1, function(row) {
    my_mesh <- rayvertex::xy_rect_mesh(
      material = rayvertex::material_list(
        texture_location = row$low_res_img
      ),
      scale = c(200, 200, 200)
    )

    rayshader::render_raymesh(
      extent = st_bbox(nama_sf), long = row$geometry[1], lat = row$geometry[2], altitude = 6500, zscale = 10,
      raymesh = my_mesh, heightmap = phm, angle = c(180, 0, 0)
    )
  })


output_folder <- file.path(getwd(), "output", "output_movie.mp4")
output_file <- file.path(getwd(), "output", "output_movie3.mp4")
rayshader::render_movie(filename = output_file, zoom = 0.1, phi = 30)

# Trying to save as an html widget return error 9 from pandoc, which it seems to be an error due to too much memory being used.
# widget <- rgl::rglwidget()
# filename <- tempfile(fileext = ".html")
# htmlwidgets::saveWidget(rgl::rglwidget(), filename)
# browseURL(filename)

#endddd


# this is for hight quality render, takes a long time, careful, like 20min
rayshader::render_highquality(
  filename = "mekar-2020.png",
  preview = TRUE,
  interactive = FALSE,
  light = TRUE,
  lightdirection = c(
    315, 310, 315, 310
  ),
  lightintensity = c(
    1000, 1500, 150, 100
  ),
  lightaltitude = c(
    15, 15, 80, 80
  ),
  ground_material = rayrender::microfacet(roughness = .6),
  width = 4000,
  height = 4000
)
