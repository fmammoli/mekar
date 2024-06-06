Sys.setenv(LANG = "en")
library(tidyverse)
library(sf)
library(terra)
library(tidyterra)
library(lidR)
library(elevatr)
library(httr2)
library(tidygeocoder)
library(rgl)
create_reqs <- function(url_string) {
  reqs <- purrr::map(url_string, function(item){
    req <- httr2::request(item) |>
      httr2::req_user_agent("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36") |> # nolint: line_length_linter.
      httr2::req_progress() |>
      httr2::req_cache(tempdir(), debug = TRUE)
    return(req)
  })
  return(reqs)
}


donwload_sp_quadricles_shapefile <- function(url_string) {
  dtm_grid_shapefile_url <- "https://geosampa.prefeitura.sp.gov.br/PaginasPublicas/downloadArquivo.aspx?orig=DownloadCamadas&arq=21_Articulacao%20de%20Imagens%5C%5CArticula%E7%E3o%20MDT%5C%5CShapefile%5C%5CSIRGAS_SHP_quadriculamdt&arqTipo=Shapefile" # nolint: line_length_linter.
  req <- create_reqs(dtm_grid_shapefile_url)
  return(req)
}

build_lidar_url <- function(cell_code) {
  start <- "https://geosampa.prefeitura.sp.gov.br/PaginasPublicas/downloadArquivo.aspx?orig=DownloadMapaArticulacao&arq=MDS_2020%5C" # nolint: line_length_linter.
  end <- ".zip&arqTipo=MAPA_ARTICULACAO"
  url <- paste0(start, cell_code, end)
  return(url)
}

  
quadricle <- "3314-221"

sirgas_2000_23s_crs <- "epsg:31983"

#Por algum motivo não pode ter acento no endereço, senão o geocoding não funciona, tem que rever isso.
addresses <- tibble::tribble(
  ~name,              ~addr,
  "Copan",             "Av. Ipiranga, 200, Sao Paulo - SP, 01046-010
"
)

lat_longs <- addresses %>%
  geocode(addr, method = "osm", lat = latitude, long = longitude, verbose = TRUE)

first(lat_longs)

class(lat_longs)

# Always longitude first, than latitude
b_copan <- sf::st_as_sf(lat_longs, coords = c("longitude", "latitude"), crs = sf::st_crs(4326)) |>
  st_transform(crs = st_crs(31983)) |>
  st_buffer(200)
b_copan
shp_path <- file.path(getwd(), "SIRGAS_SHP_quadriculamdt/")
shp_path
quads <- sf::st_read(shp_path, crs = sf::st_crs(31983))
quads

st_transform(b_copan, crs = sf::st_crs(quads))


ggplot(quads) +
  geom_sf() +
  geom_sf(data = b_copan, mapping = aes(fill = "blue"))

row_nums <- st_intersects(b_copan, quads) |> unlist()
a <- quads[row_nums |> unlist(), ]

lidar_donwload_path <- file.path(getwd(), "lidar", paste0(a$qmdt_cod, ".zip"))


reqs <- build_lidar_url(a$qmdt_cod) |> create_reqs()
try(resps <- reqs |>
  httr2::req_perform_parallel(
    paths = lidar_donwload_path,
    on_error = "stop",
    progress = TRUE
  )
)
resp_has_body(resps[[1]])

resps |> purrr::map(function(resp) {
  unzip(resp$body[1], exdir = file.path(getwd(), "lidar"), overwrite = TRUE)
  unlink(resp$body[1])
})

lidar_path <- file.path(getwd(), "lidar")
filter <- paste0(
  "-inside_circle ",
  b_copan |> sf::st_centroid() |> sf::st_coordinates() |> as.list() |> paste0(collapse = " "),
  " ",
  sf::st_distance(sf::st_centroid(b_copan), sf::st_boundary(b_copan)) |> as.numeric() |> round()
)
filter
catalog <- lidR::readALSLAScatalog(lidar_path)
catalog |> lidR::plot()
las_check(catalog)
coords <- b_copan |> sf::st_centroid() |> sf::st_coordinates() |> as.list()
coords

copan_point <- sf::st_as_sf(lat_longs, coords = c("longitude", "latitude"), crs = sf::st_crs(4326)) |>
  st_transform(crs = st_crs(31983))

sf::st_coordinates(copan_point)[,1]

roi <- lidR::clip_circle(catalog, sf::st_coordinates(copan_point)[, 1], sf::st_coordinates(copan_point)[,2], 200)

#plotting with colored height
plot(roi, size = 2, axis = TRUE, legend = TRUE)
#set the window size after the plotting
rgl::par3d(windowRect = c(100, 100, 1000, 800))

#plot with colored Classification
plot(roi, size = 2, axis = TRUE, legend = TRUE, color = "Classification")
#set the window size after the plotting
rgl::par3d(windowRect = c(100, 100, 1000, 800))
