library(leaflet)
library(exifr)
library(tidyverse)
library(sf)
library(webshot2)
library(mapview)

library(elevatr)
library(rayshader)
library(rsi)

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

files_1 <- list.files(file.path(getwd(), "20240501"), full.names = TRUE) |>
  exifr::read_exif(tags = gps_tags)
print(files_1 |> as_tibble() |> colnames())
print(files_1 |> as_tibble())

files_2 <- list.files(file.path(getwd(), "20240502"), full.names = TRUE) |>
  exifr::read_exif(tags = gps_tags)
print(files_2 |> as_tibble() |> colnames())
print(files_2 |> as_tibble())

files <- files_1 %>% add_row(files_2)

colnames(files)[2] <- "lat"
colnames(files)[3] <- "long"
colnames(files)

files_sf <- sf::st_as_sf(files, coords = c("long", "lat"), crs = sf::st_crs(4326)) |> sf::st_transform( crs = sf::st_crs(4326))
mekar <- sf::st_read(file.path(getwd(), "Mekar Raya GIS Data")) |> sf::st_transform( crs = sf::st_crs(4326))

centroid_coords <- sf::st_as_sfc(st_bbox(mekar)) %>% sf::st_centroid(bb) %>% st_coordinates()
centroid_coords

ggplot(mekar) +
  geom_sf(mapping = aes()) +
  geom_sf(data = sf::st_as_sfc(st_bbox(mekar)) %>% sf::st_centroid(bb), size = 2, shape = 23, fill = "blue") + 
  geom_sf(data = files_sf,  color = "orange")



tooltip_text <- paste0(
  "File: ", basename(files$SourceFile), "<br/>",
  "Latitude: ", files$lat, "<br/>",
  "Longitude: ", files$long, "<br/>",
  "Altitude: ", files$GPSAltitude, "<br/>",
  "Image: ", "<img src=\"", files$SourceFile, "\" width=400 />",
  sep = ""
) %>% lapply((htmltools::HTML))

mekar

path <- file.path(getwd())

map <- leaflet::leaflet(files_sf) %>%
  leaflet::addTiles() %>%
  leaflet::addProviderTiles("Esri.WorldImagery") %>%
  leaflet::addPolygons(data = mekar, color = "green") %>%
  leaflet::addCircleMarkers(
    data = filter(files_sf, grepl("*.HEIC", SourceFile)),
    fillColor = "lightblue",
    stroke = FALSE,
    radius = 8,
    fillOpacity = 0.4,
    color = "white",
    opacity = 0.5,
    label = tooltip_text
  ) %>%
  leaflet::addCircleMarkers(
    data = filter(files_sf, grepl("*.MOV", SourceFile)),
    fillColor = "orange",
    stroke = FALSE,
    radius = 8,
    fillOpacity = 0.6,
    opacity = 0.5,
    color = "white",
    label = tooltip_text
  )
map
res <- mapview::mapshot2(map, url = paste0(file.path(getwd(), "index.html")))
browseURL(paste0(file.path(getwd(), "index.html")))


# End creating leaflet

#This is not working
# my_aoi <- st_as_sfc(st_bbox(mekar))
# my_aoi
# sa_landsat <- get_landsat_imagery(
#   my_aoi,
#   start_date = as.character("2024-04-01"),
#   end_date = as.character("2024-04-31"),
#   output_filename = tempfile(fileext = ".tif")
# )
# sa_landsat

elev <- elevatr::get_elev_raster(mekar, z = 12)

elmat <- rayshader::raster_to_matrix(elev)

elmat %>%
  sphere_shade() %>%
  add_water(detect_water(elmat), color = "desert") %>%
  rayshader::plot_3d(elmat, zscale = 10, fov = 0, theta = 135, zoom = 0.75, phi = 45, windowsize = c(1000, 800))
Sys.sleep(0.2)
render_snapshot()

files_sf[2]
x <- st_coordinates(files_sf)[,"X"]
x
label_data <- tibble::tibble(X = st_coordinates(files_sf)[,"X"], Y = st_coordinates(files_sf)[,"Y"], SourceFile = basename(files_sf$SourceFile))

label_data[1,]
print(label_data)
labels <- label_data %>% as.data.frame() %>%
  purrr::map(function(item) {
  print(item[1])
  # render_label(
  #   elmat,
  #   x = item$X,
  #   y = item$Y,
  #   z = 1000,
  #   zscale = 50,
  #   textcolor = "white",
  #   linecolor = "white",
  #   text = item$SourceFile,
  #   relativez = FALSE,
  #   textsize = 2,
  #   linewidth = 5
  # )
  
})
print(labels)
render_label(montereybay, x = 50, y = 270, z = 1000, zscale = 50,  textcolor = "white", linecolor = "white",
             text = "Some Text", relativez = FALSE, textsize = 2, linewidth = 5)


render_label(elmat, x = label_data[20, "X"], y = label_data[20, "Y"], z = 10000, zscale = 50,  textcolor = "black", linecolor = "black",
             text = label_data[20, "SourceFile"], relativez = FALSE, textsize = 2, linewidth = 5) 
