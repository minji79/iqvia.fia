# 1. setting
setwd("/dcs07/hpm/data/iqvia_fia/tutorial/gather_by_drug/r") # file directory

install.packages(c("readstata13", "fst", "data.table", "future.apply"))
library(readstata13)
library(fst)
library(data.table)
library(future.apply)

# 2. Conversion function
convert_dta_to_fst <- function(infile, outfile = sub("\\.dta$", ".fst", infile)) {
  df <- readstata13::read.dta13(
    infile,
    convert.factors = FALSE,
    generate.factors = FALSE,
    convert.dates = TRUE
  )
  setDT(df)  # data.table for speed
  fst::write_fst(df, outfile, compress = 50)
  invisible(outfile)
}

# Input/output dirs
in_dir  <- "/dcs07/hpm/data/iqvia_fia/reduced"
out_dir <- "/dcs07/hpm/data/iqvia_fia/reduced"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# List all .dta files
files <- list.files(in_dir, pattern = "\\.dta$", full.names = TRUE)

# select files you want to convert
selected_files <- files[basename(files) %in% c("file1.dta", "file2.dta")]

# Loop one by one
for (f in selected_files) {
  out_file <- file.path(out_dir, paste0(tools::file_path_sans_ext(basename(f)), ".fst"))
  if (!file.exists(out_file)) {
    message("Converting: ", basename(f))
    tryCatch({
      convert_dta_to_fst(f, out_file)
    }, error = function(e) {
      message("❌ Failed: ", basename(f), " — ", e$message)
    })
  } else {
    message("Skipping (already exists): ", basename(f))
  }
}
