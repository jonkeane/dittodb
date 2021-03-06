% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/utils.R
\name{dittodb_debug_level}
\alias{dittodb_debug_level}
\title{Get the dittodb debug level and evaluate if it is above a level}
\usage{
dittodb_debug_level(level)
}
\arguments{
\item{level}{the level to test against (greater than or equal to)}
}
\value{
logical
}
\description{
Get the dittodb debug level and evaluate if it is above a level
}
\examples{
dittodb_debug_level(0)
dittodb_debug_level(2)
}
\keyword{internal}
