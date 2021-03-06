#' Add Parsed Street Address Data to Source Data Set
#'
#' @description Adds standardized address and, optionally, unnest house ranges. All logical variables
#'    that were created during the data cleaning process (i.e. \code{pm.hasHouse}, \code{pm.hasDir}, etc.)
#'    are removed at this stage.
#'
#' @usage pm_replace(source, street, intersect, operator = "at", unnest = FALSE)
#'
#' @param source Original source data to merge clean addresses with.
#' @param street A postmastr object created with \link{pm_prep} with street addresses that has been readied
#'     for replacement by fully parsing the data.
#' @param intersect A postmastr object created with \link{pm_prep} with intersections that has been readied
#'     for replacement by fully parsing the data.
#' @param operator A character scalar to be used as the intersection operator (between the 'x' and 'y' sides
#'     of the intersection).
#' @param unnest A logical scalar; if \code{TRUE}, house ranges will be unnested (i.e. a house range that
#'    has been expanded to cover four addresses with \code{\link{pm_houseRange_parse}} will be converted
#'    from a single observation to four observations, one for each house number). If \code{FALSE} (default),
#'    the single observation will remain.
#'
#' @return The source data with a parsed address elements added to the left side of the source data.
#'
#' @importFrom dplyr %>%
#' @importFrom dplyr everything
#' @importFrom dplyr left_join
#' @importFrom dplyr select
#' @importFrom dplyr select_if
#' @importFrom dplyr starts_with
#' @importFrom tidyr unnest
#'
#' @export
pm_replace <- function(source, street, intersect, operator = "at", unnest = FALSE){

  # global bindings
  . = pm.id = pm.houseRange = pm.houseFrac = pm.house = pm.hasHouseFracRange = pm.type = pm.uid = ...pm.id = ...pm.uid = ...pm.type = NULL

  # check for objects and key variables
  if (missing(street) == FALSE){

    if (pm_has_uid(street) == FALSE){
      stop("The variable 'pm.uid' is missing from the object supplied for the 'street' argument. Create a postmastr object with pm_identify and pm_prep and fully parse it before proceeding.")
    }

    if ("pm.street" %in% names(street) == FALSE){
      stop("The object supplied for the 'street' argument is missing the 'pm.street' variable and therefore is not fully parsed. postmastr objects must be fully parsed before replacement.")
    }

  }

  if (missing(intersect) == FALSE){

    if (pm_has_uid(intersect) == FALSE){
      stop("The variable 'pm.uid' is missing from the object supplied for the 'intersect' argument. Create a postmastr object with pm_identify and pm_prep and fully parse it before proceeding.")
    }

    if ("pm.street" %in% names(intersect) == FALSE){
      stop("The object supplied for the 'intersect' argument is missing the 'pm.street' variable and therefore is not fully parsed. postmastr objects must be fully parsed before replacement.")
    }

  }

  if (pm_has_uid(source) == FALSE){
    stop("The variable 'pm.uid' is missing from the source data. Source data should be processed with pm_identify before parsing.")
  }

  # determine rebuild operations
  if (missing(street) == TRUE & missing(intersect) == TRUE){

    stop("At least one parsed data set must be supplied for 'street' or 'intersect'.")

  } else if (missing(street) == FALSE & missing(intersect) == TRUE){

    out <- pm_replace_street(street, source = source, unnest = unnest)

  } else if (missing(street) == TRUE & missing(intersect) == FALSE){

    out <- pm_replace_intersect(intersect, source = source, operator = operator)

  } else if (missing(street) == FALSE & missing(intersect) == FALSE){

    source %>%
      dplyr::filter(pm.type != "intersection") %>%
      pm_replace_street(street, source = ., unnest = unnest) -> street_sub

    source %>%
      dplyr::filter(pm.type == "intersection") %>%
      pm_replace_intersect(intersect, source = ., operator = operator) -> intersect_sub

    dplyr::bind_rows(street_sub, intersect_sub) %>%
      dplyr::arrange(pm.id) -> out

  }

  # rename ids
  out <- dplyr::rename(out, ...pm.id = pm.id, ...pm.uid = pm.uid, ...pm.type = pm.type)

  # re-order variables
  vars <- pm_reorder_replaced(out, style = "replace")

  # re-order data
  out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, vars$pm.vars, vars$source.vars)

  # rename
  out <- dplyr::rename(out, pm.id = ...pm.id, pm.uid = ...pm.uid, pm.type = ...pm.type)

  # return output
  return(out)

}

#
pm_replace_street <- function(.data, source, unnest){

  pm.hasHouseFracRange = pm.house = pm.houseFrac = pm.houseRange = NULL

  # remove logical variables from postmastr object as well as any missing all values
  .data %>%
    dplyr::select(-dplyr::starts_with("pm.has")) %>%
    dplyr::select_if(function(x) !(all(is.na(x)))) -> .data

  # combine data
  out <- dplyr::left_join(source, .data, by = "pm.uid")

  # optionally unnest and clean-up unnested data
  if (unnest == TRUE){

    out %>%
      tidyr::unnest() %>%
      dplyr::mutate(pm.houseFrac =
                      ifelse(is.na(pm.houseRange) == FALSE & is.na(pm.houseFrac) == FALSE,
                             NA, pm.houseFrac)) %>%
      dplyr::mutate(pm.house = ifelse(is.na(pm.houseRange) == FALSE, pm.houseRange, pm.house)) %>%
      dplyr::mutate(pm.hasHouseFracRange = ifelse(stringr::str_detect(
        string = stringr::word(pm.house, -1),
        pattern = "[1-9]/") == TRUE, TRUE, FALSE)) %>%
      dplyr::mutate(pm.houseFrac = ifelse(pm.hasHouseFracRange == TRUE, stringr::word(pm.house, -1), pm.houseFrac)) %>%
      dplyr::mutate(pm.house = ifelse(pm.hasHouseFracRange == TRUE &
                                        stringr::str_count(string = pm.house, pattern = "\\S+") == 2,
                                      stringr::word(pm.house, 1),
                                      pm.house)) %>%
      dplyr::mutate(pm.house = ifelse(pm.hasHouseFracRange == TRUE &
                                        stringr::str_count(string = pm.house, pattern = "\\S+") > 2,
                                      stringr::word(pm.house, start = 1, end = -2),
                                      pm.house)) %>%
      dplyr::select(-pm.houseRange, -pm.hasHouseFracRange) -> out

  }


  # return output
  return(out)

}

#
pm_replace_intersect <- function(.data, source, operator){

  # remove logical variables from postmastr object as well as any missing all values
  .data %>%
    dplyr::select(-dplyr::starts_with("pm.has")) %>%
    dplyr::select_if(function(x) !(all(is.na(x)))) %>%
    dplyr::mutate(pm.intersect = "at") -> .data

  # combine data
  out <- dplyr::left_join(source, .data, by = "pm.uid")

  # return output
  return(out)

}

#' Re-construct Street Addressed from Parsed Elements
#'
#' @description Create a single address from parsed components.
#'
#' @details Re-constructed street addresses will can be either \code{"full"} or \code{"short"} depending
#'     on the \code{output} parameter's argument. Intersections will always be re-constructed in full.
#'
#' @usage pm_rebuild(.data, output, new_address, include_commas = FALSE, include_units = TRUE,
#'    keep_parsed = "no", side = "right", left_vars, keep_ids = FALSE, locale = "us")
#'
#' @param .data An object with raw and parsed data created by \code{\link{pm_rebuild}}
#' @param output Describes the format of the output address. One of either \code{"full"} or \code{"short"}.
#'     A short address contains, at the most, a house number, street directionals, a street name,
#'     a street suffix, and a unit type and number. A full address contains all of the selements of a
#'     short address as well as, at the most, a city, state, and postal code.
#' @param new_address Optional; name of new variable to store rebuilt address in. If not specified,
#'     the re-build addressed will be stored in \code{pm.address}.
#' @param include_commas A logical scalar; if \code{TRUE}, a comma is added both before and after the city
#'     name in rebuild addresses. If \code{FALSE} (default), no punctuation is added.
#' @param include_units A logical scalar; if \code{TRUE} (default), unit data will be included in the
#'     re-constructed address. If \code{FALSE}, units will not be included.
#' @param keep_parsed Character string; if \code{"yes"}, all parsed elements will be
#'     added to the source data after replacement. If \code{"limited"}, only the \code{pm.city},
#'     \code{pm.state}, and postal code variables will be retained. Otherwise, if \code{"no"},
#'     only the rebuilt address will be added to the source data (default).
#' @param side One of either \code{"left"} or \code{"right"} - should parsed data be placed to the left
#'     or right of the original data? Placing data to the left may be useful in particularly wide
#'     data sets.
#' @param left_vars A character scalar or vector of variables to place on the left-hand side of
#'     the output when \code{side} is equal to \code{"middle"}.
#' @param keep_ids Logical scalar; if \code{TRUE}, the identification numbers
#'     will be kept in the source data after replacement. Otherwise, if \code{FALSE},
#'     they will be removed (default).
#' @param locale A string indicating the country these data represent; the only
#'     current option is "us" but this is included to facilitate future expansion.
#'
#' @export
pm_rebuild <- function(.data, output, new_address, include_commas = FALSE, include_units = TRUE,
                       keep_parsed = "no", side = "right", left_vars, keep_ids = FALSE, locale = "us"){

  # global bindings
  pm.id = pm.uid = pm.houseRange = pm.city = ...temp_address = ...pm.id = ...pm.uid = pm.type = ...pm.type = NULL

  # save parameters to list
  paramList <- as.list(match.call())

  # unquote new_var
  if (missing(new_address) == FALSE){
    if (!is.character(paramList$new_address)) {
      varQ <- rlang::enquo(new_address)
    } else if (is.character(paramList$new_address)) {
      varQ <- rlang::quo(!! rlang::sym(new_address))
    }
  } else if (missing(new_address) == TRUE){
    varQ <- rlang::quo(!! rlang::sym("pm.address"))
  }

  # convert left_vars to expression
  if (missing(left_vars) == FALSE){
    left_varsE <- rlang::enexpr(left_vars)
  }

  # determine rebuild type
  types <- unique(.data$pm.type)

  # rebuild addresses
  if ("intersection" %in% types == FALSE){

    # rebuild street addresses
    .data %>%
      dplyr::filter(pm.type != "intersection") %>%
      pm_rebuild_street(output = output, include_commas = include_commas,
                        include_units = include_units, keep_parsed = keep_parsed) -> out

  } else if ("intersection" %in% types == TRUE & length(types) == 1){

    # rebuild intersections
    .data %>%
      dplyr::filter(pm.type == "intersection") %>%
      pm_rebuild_intersect(output = output, include_commas = include_commas) -> out

  } else if ("intersection" %in% types == TRUE & length(types) > 1){

    # rebuild street addresses
    .data %>%
      dplyr::filter(pm.type != "intersection") %>%
      pm_rebuild_street(output = output, include_commas = include_commas,
                        include_units = include_units, keep_parsed = keep_parsed) -> street_sub

    # rebuild intersections
    .data %>%
      dplyr::filter(pm.type == "intersection") %>%
      pm_rebuild_intersect(output = output, include_commas = include_commas) -> intersect_sub

    # add back together
    dplyr::bind_rows(street_sub, intersect_sub) %>%
      dplyr::arrange(pm.id) -> out

  }

  # rename ids
  out <- dplyr::rename(out, ...pm.id = pm.id, ...pm.uid = pm.uid, ...pm.type = pm.type)

  # remove parsed variables
  if (keep_parsed == "no"){

    # re-order data
    if (side == "right"){

      out %>%
        dplyr::select(-dplyr::starts_with("pm.")) %>%
        dplyr::select(-...temp_address, dplyr::everything()) -> out

    } else if (side == "left" | side == "middle"){

      out %>%
        dplyr::select(-dplyr::starts_with("pm.")) %>%
        dplyr::select(...pm.id, ...pm.uid, ...pm.type, ...temp_address, dplyr::everything()) -> out

      if (side == "middle"){
        out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, !!left_varsE, dplyr::everything())
      }
    }

  } else if (keep_parsed == "yes"){

    # determine variable order
    vars <- pm_reorder_replaced(out, style = "rebuild")

    # re-order data
    if (side == "right"){
      out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, vars$source.vars, ...temp_address, vars$pm.vars)
    } else if (side == "left" | side == "middle"){

      out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, ...temp_address, vars$pm.vars, vars$source.vars)

      if (side == "middle"){
        out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, !!left_varsE, dplyr::everything())
      }
    }
  } else if (keep_parsed == "limited"){

    # determine variable order
    vars <- pm_reorder_replaced(out, style = "limited")

    # re-order data
    if (side == "right"){
      out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, vars$source.vars, ...temp_address, vars$pm.vars)
    } else if (side == "left" | side == "middle"){

      out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, ...temp_address, vars$pm.vars, vars$source.vars)

      if (side == "middle"){
        out <- dplyr::select(out, ...pm.id, ...pm.uid, ...pm.type, !!left_varsE, dplyr::everything())
      }
    }
  }

  # rename ids if kept; drop if discarded
  if (keep_ids == TRUE){
    out <- dplyr::rename(out, pm.id = ...pm.id, pm.uid = ...pm.uid, pm.type = ...pm.type)
  } else if (keep_ids == FALSE){
    out <- dplyr::select(out, -...pm.id, -...pm.uid, -...pm.type)
  }

  # rename ...temp_address
  out <- dplyr::rename(out, !!varQ := ...temp_address)

  # return output
  return(out)

}

pm_rebuild_street <- function(.data, output, include_commas, include_units, keep_parsed){

  # global bindings
  ...temp_address = pm.city = pm.unitType = pm.unitNum = pm.id = pm.uid = pm.type = pm.houseRange = pm.house = NULL

  # optionally add commas
  if (include_commas == TRUE & "pm.city" %in% names(.data) == TRUE){
    .data <- dplyr::mutate(.data, pm.city = stringr::str_c(", ", pm.city, ","))
  }

  # optionally remove units
  if (include_units == FALSE){
    if ("pm.unitType" %in% names(.data) == TRUE){
      .data <- dplyr::select(.data, -pm.unitType)
    }

    if ("pm.unitNum" %in% names(.data) == TRUE){
      .data <- dplyr::select(.data, -pm.unitNum)
    }
  }

  # determine end
  if (output == "short"){

    if ("pm.unitNum" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.unitNum"))
    } else if ("pm.unitType" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.unitType"))
    } else if ("pm.sufDir" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.sufDir"))
    } else if ("pm.streetSuf" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.streetSuf"))
    } else if ("pm.street" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.street"))
    }

  } else if (output == "full"){

    if ("pm.zip4" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.zip4"))
    } else if ("pm.zip" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.zip"))
    } else if ("pm.state" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.state"))
    } else if ("pm.city" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.city"))
    }

  }

  # move pm.houseRange
  if (keep_parsed == "yes" & "pm.houseRange" %in% names(.data) == TRUE){
    .data <- dplyr::select(.data, pm.id, pm.uid, pm.type, pm.houseRange, dplyr::everything())
  } else if ((keep_parsed == "no" | keep_parsed == "limited") & "pm.houseRange" %in% names(.data) == TRUE){
    .data <- dplyr::select(.data, -pm.houseRange)
  }

  # rebuild
  .data %>%
    tidyr::unite(...temp_address, pm.house:!!endQ, sep = " ", remove = FALSE) %>%
    dplyr::mutate(...temp_address = stringr::str_replace_all(...temp_address, pattern = "\\bNA\\b", replacement = "")) %>%
    dplyr::mutate(...temp_address = stringr::str_replace_all(...temp_address, pattern = " , ", replacement = ", ")) %>%
    dplyr::mutate(...temp_address = stringr::str_squish(...temp_address)) %>%
    dplyr::select(pm.id, pm.uid, pm.type, ...temp_address, dplyr::everything()) -> .data

}

pm_rebuild_intersect <- function(.data, output, include_commas){

  # global bindings
  pm.city = pm.id = pm.uid = pm.type = ...pm.id = ...pm.uid = ...pm.type = ...temp_address = NULL

  # optionally add commas
  if (include_commas == TRUE & "pm.city" %in% names(.data) == TRUE){
    .data <- dplyr::mutate(.data, pm.city = stringr::str_c(", ", pm.city, ","))
  }

  # determine start
  if ("pm.preDir" %in% names(.data) == TRUE){
    startQ <- rlang::quo(!! rlang::sym("pm.preDir"))
  } else if ("pm.street" %in% names(.data) == TRUE){
    startQ <- rlang::quo(!! rlang::sym("pm.street"))
  }

  # determine end
  if (output == "full"){

    if ("pm.zip4" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.zip4"))
    } else if ("pm.zip" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.zip"))
    } else if ("pm.state" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.state"))
    } else if ("pm.city" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.city"))
    }

  } else if (output == "short"){

    if ("pm.sufDir.y" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.sufDir.y"))
    } else if ("pm.streetSuf.y" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.streetSuf.y"))
    } else if ("pm.street.y" %in% names(.data) == TRUE){
      endQ <- rlang::quo(!! rlang::sym("pm.street.y"))
    }

  }

  # rename ids
  .data <- dplyr::rename(.data, ...pm.id = pm.id, ...pm.uid = pm.uid, ...pm.type = pm.type)

  # re-order variables
  vars <- pm_reorder_replaced(.data, style = "intersect")

  # re-order data
  .data <- dplyr::select(.data, ...pm.id, ...pm.uid, ...pm.type, vars$pm.vars, vars$source.vars)

  # rebuild
  .data %>%
    tidyr::unite(...temp_address, !!startQ:!!endQ, sep = " ", remove = FALSE) %>%
    dplyr::mutate(...temp_address = stringr::str_replace_all(...temp_address, pattern = "\\bNA\\b", replacement = "")) %>%
    dplyr::mutate(...temp_address = stringr::str_replace_all(...temp_address, pattern = " , ", replacement = ", ")) %>%
    dplyr::mutate(...temp_address = stringr::str_squish(...temp_address)) %>%
    dplyr::mutate(...temp_address = ifelse(stringr::str_detect(string = ...temp_address, pattern = " ,") == TRUE,
                                           stringr::str_replace(string = ...temp_address, pattern = " ,", replacement = ","),
                                           ...temp_address)) %>%
    dplyr::select(...pm.id, ...pm.uid, ...pm.type, ...temp_address, dplyr::everything()) -> .data

  # re-order variables
  vars <- pm_reorder_replaced(.data, style = "rebuild")

  # re-order data and rename
  .data %>%
    dplyr::select(...pm.id, ...pm.uid, ...pm.type, ...temp_address, vars$pm.vars, vars$source.vars) %>%
    dplyr::rename(pm.id = ...pm.id, pm.uid = ...pm.uid, pm.type = ...pm.type) -> .data

  # return output
  return(.data)

}

# re-order variables
pm_reorder_replaced <- function(.data, style){

  # global bindings
  ...pm.id = ...pm.uid = ...pm.type = ...temp_address = NULL

  # create vector of current pm variables in data
  .data %>%
    dplyr::select(dplyr::starts_with("pm.")) %>%
    names() -> pmVarsCurrent

  # create vector of original source data variables
  if (style == "replace" | style == "intersect"){

    .data %>%
      dplyr::select(-dplyr::starts_with("pm."), -...pm.id, -...pm.uid, -...pm.type) %>%
      names() -> sourceVars

  } else if (style == "rebuild" | style == "limited"){

    .data %>%
      dplyr::select(-dplyr::starts_with("pm."), -...pm.id, -...pm.uid, -...pm.type, -...temp_address) %>%
      names() -> sourceVars

  }

  # master list of variables for pm objects
  if (style == "replace" | style == "rebuild"){
    master <- data.frame(
      master.vars = c("pm.house", "pm.houseRage","pm.houseFrac", "pm.houseSuf",
                      "pm.preDir", "pm.street", "pm.streetSuf", "pm.sufDir",
                      "pm.unitType", "pm.unitNum",  "pm.city",
                      "pm.state", "pm.zip", "pm.zip4", "pm.intersect",
                      "pm.preDir.y", "pm.street.y", "pm.streetSuf.y", "pm.sufDir.y"),
      stringsAsFactors = FALSE
    )
  } else if (style == "limited"){
    master <- data.frame(
      master.vars = c("pm.city", "pm.state", "pm.zip", "pm.zip4"),
      stringsAsFactors = FALSE
    )
  } else if (style == "intersect"){
    master <- data.frame(
      master.vars = c("pm.preDir", "pm.street", "pm.streetSuf", "pm.sufDir", "pm.intersect",
                      "pm.preDir.y", "pm.street.y", "pm.streetSuf.y", "pm.sufDir.y",
                      "pm.city", "pm.state", "pm.zip", "pm.zip4",
                      "pm.house", "pm.houseRage","pm.houseFrac", "pm.houseSuf", "pm.unitType", "pm.unitNum"),
      stringsAsFactors = FALSE
    )
  }

  # create data frame of current variables
  working <- data.frame(
    master.vars = c(pmVarsCurrent),
    working.vars = c(pmVarsCurrent),
    stringsAsFactors = FALSE
  )

  # join master and working data
  joined <- dplyr::left_join(master, working, by = "master.vars")

  # create vector of re-ordered variables
  vars <- stats::na.omit(joined$working.vars)

  out <- list(
    pm.vars = c(vars),
    source.vars = c(sourceVars)
  )

  return(out)

}
