# Update example_study_config data object from source file

# Source the updated configuration
source("inst/config_repository/example_study.R")

# Save as package data
usethis::use_data(example_study_config, overwrite = TRUE)