% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/prep.R
\name{pm_has_address}
\alias{pm_has_address}
\title{Validate postmastr Address Variable}
\usage{
pm_has_address(obj)
}
\arguments{
\item{obj}{Object to test}
}
\value{
A logical scalar that is \code{TRUE} if the variable remains;
    it will return \code{FALSE} otherwise.
}
\description{
This function tests to see whether the address variable
    \code{pm.address} remains in an object. It is used as part of the
    parsing functions, and is exported so that it can be used interactively a
    s well.
}
