# Read the custom config file for these batch runs
library(ini)
config = read.ini("config.ini")

# Path to the midscalculator code
calcpath = "../../../MIDSCalculator/src/"

# check if all packages are installed and load libraries
# some overhead as this also includes all the rshiny stuff and visuals
source(paste0(calcpath,"packages.R"))
pkgLoad()

# load midscalculator functions
default_schema = config$app$default_schema
source(paste0(calcpath,"parse_json_schema.R"))
source(paste0(calcpath,"parse_data_formats.R"))
source(paste0(calcpath,"MIDS-calc.R"))

# load the local sssom mapping into a json schema compatible with the
# midscalculator code
# localpath = T ensures the mapping is taken from this repo, not the calculator one
schema = parse_sssom(config = config,localpath=T)

#
## Copied code from midscalculator below, to create the lists used during the
## calculation process
list_UoM <- list()
#Loop trough the values
n_values <- length(schema$unknownOrMissing)
for (l in 1:n_values) {
  value = schema$unknownOrMissing[[l]]$value[[1]]
  #only take into account values which do not count for mids
  if (schema$unknownOrMissing[[l]]$midsAchieved == FALSE) {
    #check if there is a property, otherwise it relates to all properties
    if ("property" %in% names(schema$unknownOrMissing[[l]])){
      prop <- schema$unknownOrMissing[[l]]$property[[1]]
    } else {
      prop <- "all"
    }
    #add to list
    if (prop %in% names(list_UoM)){
      list_UoM[[prop]] <- append(list_UoM[[prop]], value)
    } else {
      list_UoM[[prop]] <- value
    }
  }
}

midsschema <- schema[grep("mids", names(schema))]
list_criteria <- list()
list_props <- character()
#Loop trough sections
for (sect_index in seq_along(names(midsschema))){
  #Get the contents of a section
  section <- midsschema[[sect_index]] 
  #Loop through conditions
  for (cond_index in seq_along(names(section))){ 
    crits <- ""
    condition_name = names(section)[cond_index]
    # Loop trough subconditions, one of these should be true (|)
    for (subcond_index in seq_along(section[[condition_name]])){
      # get the contents (properties etc) of a single subcondition
      subcondition <- section[[condition_name]][[subcond_index]] 
      #if operator is NOT, inverse all the criteria
      if ("operator" %in% names(subcondition) && subcondition$operator == "NOT"){
        crits <- paste0(crits, "!")}
      #open brackets before the subcondition
      if (subcond_index == 1){crits <- paste0(crits, "(")}
      # Loop trough properties
      for (prop_index in seq_along(subcondition$property)){
        prop <- subcondition$property[[prop_index]]
        if (is.null(prop)){break} #if there is no property, exit this loop iterating over props, still need to check later what to do when there is no property
        #make a list of properties
        list_props <- append(list_props, prop)
        #add the property is not na
        crits <- paste0(crits, "!is.na(`", prop, "`)")
        #if there is a operator and it is not the last property, then add the matching operator to the string
        #currently does not work if there are subconditions without property! needs to be fixed 
        if (prop_index != length(subcondition$property) & "operator" %in% names(subcondition)){
          if (subcondition$operator == "OR"){crits <- paste0(crits, " | ")}
          if (subcondition$operator == "AND"){crits <- paste0(crits, " & ")}
        }
      }
      #Add | between subconditions
      if (subcond_index != length(section[[condition_name]])){crits <- paste0(crits, " | ")}
      #close brackets after subcondition
      else {crits <- paste0(crits, ")")}
    }
    #create nested list with criteria for each condition of each mids level
    list_criteria[[names(midsschema[sect_index])]][[condition_name]] <- crits
  }
}

list_extra_props <- c("[dwc:Occurrence]dwc:datasetKey",
                      "[dwc:Occurrence]dwc:countryCode",
                      "[dwc:Occurrence]dwc:kingdom",
                      "[dwc:Occurrence]dwc:phylum", 
                      "[dwc:Occurrence]dwc:class",
                      "[dwc:Occurrence]dwc:order", 
                      "[dwc:Occurrence]dwc:family",
                      "[dwc:Occurrence]dwc:subfamily",
                      "[dwc:Occurrence]dwc:genus")

select_props = unique(c(list_props, list_extra_props, "gbifid"))
uom = list_UoM$all

## end of copied code

# remove the class and namespace for the calculation with the tsv file from the sql api
# this file has no metadata and thus no easy way to set those
# also all variables are lower case from this api
select_props_truncated = select_props %>%
  gsub(".*:","",.) %>%
  tolower()

## custom function to remove the class and namespace from the filter arguments
## that have been set up by the midscalculator code by default
## also sets lower case
clean_backtick_texts <- function(x) {
  if (is.list(x)) {
    lapply(x, clean_backtick_texts)
  } else if (is.character(x)) {
    sapply(x, function(str) {
      # Find all substrings enclosed in backticks
      matches <- gregexpr("`[^`]*`", str)[[1]]
      if (matches[1] == -1) return(str)  # No matches, return original
      
      # Extract those substrings
      substrings <- regmatches(str, gregexpr("`[^`]*`", str))[[1]]
      
      # Process each: remove everything before final colon
      cleaned <- sapply(substrings, function(s) {
        content <- sub("^`(.*)`$", "\\1", s)
        trimmed <- sub(".*:", "", content)
        paste0("`", tolower(trimmed), "`")
      })
      
      # Replace in original string
      regmatches(str, gregexpr("`[^`]*`", str))[[1]] <- cleaned
      str
    }, USE.NAMES = FALSE)
  } else {
    x
  }
}

list_criteria_truncated = list_criteria %>%
  clean_backtick_texts()

# read the colnames of the sql api downloaded tsv
library(readr)
data_colnames = read_tsv("data/0070019-250525065834625.csv",
                    n_max=0) %>%
  colnames()

#add missing columns with all values as NA
list_props %<>% unique()
list_props_truncated = list_props %>%
  gsub(".*:","",.) %>%
  tolower()
missing <- c(list_props_truncated)[!c(list_props_truncated) %in% data_colnames] %>%
  unique()

# loop in batches of 10M through this file and calculate mids for each batch
for (ibig in 24:27) {
  # initial timestamp
  print(paste0("INIT batch ",ibig," at ",Sys.time()))
  # jump in steps of 10M, ignore colnames
  milli = 1+(ibig-1)*10000000
  
  # read the file in batch
  # col_select is not really needed and conflicts now that the colnames are read
  # elsewhere so it cannot be used
  data <- read_tsv("data/0070019-250525065834625.csv", 
                   n_max = 10000000, 
                   col_types = cols(.default = col_character()),
                   quote="",
                   #col_select = any_of(select_props_truncated),
                   na = uom,
                   skip = milli,
                   col_names = F)
  colnames(data) = data_colnames
  data[, missing] <- as.character(NA)
  
  ## slightly adapted MIDS calculation code below
  
  # change unknown or missing values for specific columns to NA
  for (i in 1:length(list_UoM)){
    colname <- names(list_UoM[i]) %>%
      gsub(".*:","",.) %>%
      tolower()
    if (colname %in% names(data)){
      data %<>%
        mutate("{colname}" := na_if(data[[colname]], list_UoM[[i]]))
    }
  }
  
  # Check if separate MIDS conditions are met -------------------------------
  
  #For each MIDS condition in the list, check if the criteria for that condition 
  #are TRUE or FALSE and add the results in a new column
  for (j in 1:length(list_criteria_truncated )){
    midslevel <- names(list_criteria_truncated [j])
    midscrit <- list_criteria_truncated [[j]]
    for (i in 1:length(midscrit)){
      columnname = paste0(midslevel,  names(midscrit[i]))
      data %<>%
        mutate("{columnname}" := !!rlang::parse_expr(midscrit[[i]]))
    }
  }
  
  # Calculate MIDS level ----------------------------------------------------
  
  #For each MIDS level, the conditions of that level and of lower levels all need to be true
  data %<>%
    mutate(MIDS_level = case_when(
      apply(data[ , grep("mids:MIDS[0-3]", names(data)), with = FALSE], MARGIN = 1, FUN = all) ~ 3,
      apply(data[ , grep("mids:MIDS[0-2]", names(data)), with = FALSE], MARGIN = 1, FUN = all) ~ 2,
      apply(data[ , grep("mids:MIDS[0-1]", names(data)), with = FALSE], MARGIN = 1, FUN = all) ~ 1,
      apply(data[ , grep("mids:MIDS0", names(data)), with = FALSE], MARGIN = 1, FUN = all) ~ 0,
      TRUE ~ -1
    ))
  
  ## end slightly adapted mids calculation code
  
  # filename of results tsv to save
  save_name = paste0("outputs/sql_results_",
                     ibig,
                     "_excl_ids.txt")
  
  # save the binary map for each mids element, and the calculated mids level
  # no other data is saved to limit storage needed
  # datasetkey and gbifid should be inferrable based on row order, but this
  # has not been verified yet
  # adding them doubles the file size, and the csv is already huge enough
  to_save = data %>%
    select(starts_with("mids")|any_of("MIDS_level")) %>%
    mutate_if(is.logical,as.integer) %>%
    #bind_cols(select(data,gbifid,datasetkey)) %>%
    write_tsv(save_name)
  
  # try to clear out RAM before the next iteration
  remove(to_save)
  remove(data)
  gc()
  
  # end of iteration timestamp
  print(paste0("FINISH batch ",ibig," at ",Sys.time()))
}
