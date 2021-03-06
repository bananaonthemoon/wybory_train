## Kod na podstawie:
## https://github.com/Nowosad/spDataLarge/blob/master/data-raw/08_pol_prez15.R (autor: Roger Bivand)

## Wybory prezydenckie z 2015 roku, pierwsza oraz druga tura (podział dla województw)


# Pierwsza tura -----------------------------------------------------------


library(tidyverse)
library(readxl)
library(writexl)

# Pobranie oraz wczytanie danych z pierwszej tury
temp <- tempfile()
download.file("https://prezydent20200628.pkw.gov.pl/prezydent20200628/data/1/csv/wyniki_gl_na_kand_po_wojewodztwach_csv.zip", temp)
unzip(temp, files="wyniki_gl_na_kand_po_wojewodztwach_utf8.csv", exdir = "dane/pobrane/tura1")
tura1 = read.csv2("dane/pobrane/tura1/wyniki_gl_na_kand_po_wojewodztwach_utf8.csv", header=TRUE, encoding = "UTF-8", stringsAsFactors=FALSE)

# Czyszczenie oraz agregowanie danych
tura1[[1]] = formatC(tura1[[1]], width=6, format="d", flag="0")
tura1[[1]] = str_sub(tura1[[1]], 1, 2) 
tura1 = select(tura1, c(1:2, 4, 19, 24, 27, 33))
names(tura1)[names(tura1) == 'X.U.FEFF.Kod.TERYT'] <- 'TERYT'


# Druga tura -----------------------------------------------------------


# Pobranie oraz wczytanie danych z drugiej tury
download.file("https://prezydent20200628.pkw.gov.pl/prezydent20200628/data/2/csv/wyniki_gl_na_kand_po_wojewodztwach_csv.zip", temp)
unzip(temp, files="wyniki_gl_na_kand_po_wojewodztwach_utf8.csv", exdir = "dane/pobrane/tura2")
tura2 = read.csv2("dane/pobrane/tura2/wyniki_gl_na_kand_po_wojewodztwach_utf8.csv", header=TRUE, encoding = "UTF-8", stringsAsFactors=FALSE)

# Czyszczenie oraz agregowanie danych
tura2[[1]] = formatC(tura2[[1]], width=6, format="d", flag="0")
tura2[[1]] = str_sub(tura2[[1]], 1, 2) 
tura2 = select(tura2, c(1:2, 4, 19, 24:26))
names(tura2)[names(tura2) == 'X.U.FEFF.Kod.TERYT'] <- 'TERYT'

# Obie tury ---------------------------------------------------------------


# Przypisanie prefiksów do kolumn w turach 
names(tura1) = paste("t1_", names(tura1), sep="")
names(tura2) = paste("t2_", names(tura2), sep="")

obie_tury = merge(tura1, tura2, by.x="t1_TERYT", by.y="t2_TERYT")

write_xlsx(obie_tury, path = "dane/wybory_woj_proc.xlsx")


# Jednostki ewidencyjne ---------------------------------------------------


library(sf)
library(rmapshaper)
library(geojsonio)

# Pobranie oraz wczytanie danych wektorowych, ustalenie układu współrzędnych
download.file("https://www.gis-support.pl/downloads/Wojewodztwa.zip", temp)
unzip(temp, exdir = "dane/pobrane")
woj = read_sf("dane/pobrane/Wojew˘dztwa.shp", stringsAsFactors=FALSE) %>%
  st_transform(crs = 2180) %>% 
  select(-c(4:29))
# Uproszczenie geometrii i zapisanie pliku w formacie geopackage (tutaj mały bajzel jest)
woj_simp = ms_simplify(woj, keep_shapes = TRUE, keep = 0.2, explode = FALSE, snap = TRUE) 
st_is_valid(woj_simp)
woj$geometry = woj_simp$geometry
write_sf(woj_simp, dsn = "dane/temp/wojewodztwa.gpkg")
woj = read_sf("dane/temp/wojewodztwa.gpkg", stringsAsFactors=FALSE)
woj = select(woj, -1)


# Łączenie danych ---------------------------------------------------------


# Łączenie danych z geometrią
wojewodztwa = merge(woj, obie_tury, by.x="JPT_KOD_JE", by.y="t1_TERYT")

wojewodztwa$t1_frek = wojewodztwa$t1_Liczba.kart.ważnych *100 / wojewodztwa$t1_Liczba.wyborców.uprawnionych.do.głosowania
wojewodztwa$t2_frek = wojewodztwa$t2_Liczba.kart.ważnych *100 / wojewodztwa$t2_Liczba.wyborców.uprawnionych.do.głosowania
wojewodztwa$t1_duda = wojewodztwa$t1_Andrzej.Sebastian.DUDA * 100 / wojewodztwa$t1_Liczba.głosów.ważnych.oddanych.łącznie.na.wszystkich.kandydatów
wojewodztwa$t1_trzaskowski = wojewodztwa$t1_Rafał.Kazimierz.TRZASKOWSKI * 100 / wojewodztwa$t1_Liczba.głosów.ważnych.oddanych.łącznie.na.wszystkich.kandydatów
wojewodztwa$t2_duda = wojewodztwa$t2_Andrzej.Sebastian.DUDA * 100 / wojewodztwa$t2_Liczba.głosów.ważnych.oddanych.łącznie.na.wszystkich.kandydatów
wojewodztwa$t2_trzaskowski = wojewodztwa$t2_Rafał.Kazimierz.TRZASKOWSKI * 100 / wojewodztwa$t2_Liczba.głosów.ważnych.oddanych.łącznie.na.wszystkich.kandydatów
wojewodztwa$t2_roznica_glosow = wojewodztwa$t2_Andrzej.Sebastian.DUDA - wojewodztwa$t2_Rafał.Kazimierz.TRZASKOWSKI
wojewodztwa$t1_roznica_glosow = wojewodztwa$t1_Andrzej.Sebastian.DUDA - wojewodztwa$t1_Rafał.Kazimierz.TRZASKOWSKI
wojewodztwa$roznica_frek = wojewodztwa$t2_frek - wojewodztwa$t1_frek

write_sf(wojewodztwa, dsn = "dane/wojewodztwa.gpkg")
