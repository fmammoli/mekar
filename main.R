library(tidyverse)
library(sf)
library(terra)
library(elevatr)
library(rayshader)
library(magrittr)
library(magick)
library(exifr)
library(mapview)

str(magick::magick_config())

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

image_files <- list.files(file.path(getwd(), "imgs"), full.names = TRUE) |>
  exifr::read_exif(tags = gps_tags)
print(image_files |> as_tibble() |> colnames())
print(image_files |> as_tibble())


video_files <- list.files(file.path(getwd(), "vids"), full.names = TRUE) |>
  exifr::read_exif(tags = gps_tags)
print(video_files |> as_tibble() |> colnames())
print(video_files |> as_tibble())

sound_files <- list.files(file.path(getwd(), "sounds"), full.names = TRUE) |>
  exifr::read_exif()
print(sound_files |> as_tibble() |> colnames())
print(sound_files |> as_tibble())


img <- magick::image_read(file.path(getwd(), "imgs", "IMG_1964.HEIC"))

attr <- magick::image_attributes(img)
print(attr)
list.files(file.path(getwd(), "Mekar Raya GIS Data"))

a <- sf::st_read(file.path(getwd(), "Mekar Raya GIS Data"))

imgs <- sf::st_as_sf(image_files, coords = c("GPSLongitude", "GPSLatitude"), crs = sf::st_crs(4326))
vids <- sf::st_as_sf(video_files, coords = c("GPSLongitude", "GPSLatitude"), crs = sf::st_crs(4326))


ggplot(imgs) +
  geom_sf(mapping = aes())

ggplot(a) +
  geom_sf(mapping = aes()) +
  geom_sf(data = imgs, size = 2, shape = 23, fill = "orange") +
  geom_sf(data = vids, size = 2, shape = 23, fill = "blue")

print(a |> as_tibble(), n = 20)

elev <- elevatr::get_elev_raster(a, z = 12)

terra::plot(elev)

#And convert it to a matrix:
elmat <- raster_to_matrix(elev)

elmat %>%
  sphere_shade(texture = "imhof1", zscale = 10) %>%
  add_water(detect_water(elmat), color = "desert") %>%
  add_shadow(ray_shade(elmat, zscale = 3), 0.5) %>%
  add_shadow(ambient_shade(elmat), 0) %>%
  plot_3d(elmat, zscale = 10, fov = 0, theta = 135, zoom = 0.75, phi = 45, windowsize = c(1000, 800))
Sys.sleep(0.2)
render_snapshot()