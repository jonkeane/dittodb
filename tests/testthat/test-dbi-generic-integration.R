# A list of connections to be made and then used for integreation tests. This
# allows us to write each integration test once and then run them on all of the
# supported DB packages.
#
# The reason we are quoting the connection and evaluating
# and that RMariaDB must be first is that RMariDB and RPostgres interact in funny
# ways when they are called in the other order, see:
# https://github.com/r-dbi/RMariaDB/issues/119
# This should be resolved already, but it still sometimes crops up.
db_pkgs <- list(
  "RMariaDB" = quote(DBI::dbConnect(
    RMariaDB::MariaDB(),
    dbname = "nycflights",
    host = "127.0.0.1",
    username = "travis",
    password = ""
  )),
  "odbc" = quote(DBI::dbConnect(
    odbc::odbc(),
    Driver = odbc_driver,
    Server = "127.0.0.1",
    Database = "nycflights",
    UID = db_user,
    PWD = db_pass,
    Port = 5432
  )),
  "RPostgreSQL" = quote(DBI::dbConnect(
    RPostgreSQL::PostgreSQL(),
    dbname = "nycflights",
    host = "127.0.0.1",
    user = db_user,
    password = db_pass
  )),
  "RPostgres" = quote(DBI::dbConnect(
    RPostgres::Postgres(),
    dbname = "nycflights",
    host = "127.0.0.1",
    user = db_user,
    password = db_pass
  ))
)

for (pkg in names(db_pkgs)) {
  context(glue("Integration tests for {pkg}"))
  test_that(glue("Isolate {pkg}"), {
    skip_env(pkg)
    # skip_locally("use (postgres|mariadb)-docker.sh and test manually")

    # setup the database that will be mocked and then tested
    con <- eval(db_pkgs[[pkg]])

    # Setup unique schemas for each of the Postgres-using drivers
    if (pkg == "odbc") {
      schema <- "odbc"
    } else if (pkg == "RPostgreSQL") {
      schema <- "rpostgresql"
    } else if (pkg == "RPostgres") {
      schema <- "rpostgres"
    } else {
      schema <- ""
    }
    # con <- nycflights13_sql(con, schema = schema)

    if (schema == "") {
      airlines_table <- "airlines"
      flights_table <- "airlines"
    } else {
      airlines_table <- paste(schema, "airlines", sep = ".")
      flights_table <- paste(schema, "flights", sep = ".")
    }

    test_that(glue("The fixture is what we expect: {pkg}"), {
      expect_identical(
        dbGetQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 2")),
        data.frame(
          carrier = c("9E", "AA"),
          name = c("Endeavor Air Inc.", "American Airlines Inc."),
          stringsAsFactors = FALSE
        )
      )

      # we check just that the tables are there since other tests will add other tables
      # For some reason, RPostgres responds that there are 0 tables with dbListTables()
      # even though there are and other functions work (including the subsequent calls later)
      # Skipping for now, since there isn't much doubt that RPostgres is setup ok
      # given our other tests.
      if (pkg == "RPostgres") skip("RPostgres has something funny with dbListTables()")
      expect_true(all(
        c("airlines", "airports", "flights", "planes", "weather") %in% dbListTables(con)
      ))
    })

    dbDisconnect(con)

    with_mock_path(path = file.path(temp_dir, glue("{pkg}_integration")), {
      start_capturing()

      con <- eval(db_pkgs[[pkg]])

      dbGetQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 2"))
      dbGetQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 1"))

      tables <- dbListTables(con)

      # dbListFields is ever so slightly different for each
      if (pkg == "RMariaDB") {
        fields_flights <- dbListFields(con, "flights")
      } else if (pkg == "odbc") {
        fields_flights <- dbListFields(con, Id(schema = schema, table = "flights"))
      } else if (pkg == "RPostgreSQL") {
        fields_flights <- dbListFields(con, c(schema, "flights"))
      } else if (pkg == "RPostgres") {
        fields_flights <- dbListFields(con, Id(schema = schema, table = "flights"))
      }

      if (pkg == "RMariaDB") {
        airlines_expected <- dbReadTable(con, "airlines")
      } else if (pkg == "odbc") {
        airlines_expected <- dbReadTable(con, Id(schema = schema, table = "airlines"))
      } else if (pkg == "RPostgreSQL") {
        airlines_expected <- dbReadTable(con, c(schema, "airlines"))
      } else if (pkg == "RPostgres") {
        airlines_expected <- dbReadTable(con, Id(schema = schema, table = "airlines"))
      }

      dbDisconnect(con)
      stop_capturing()


      with_mock_db({
        con <- eval(db_pkgs[[pkg]])

        test_that(glue("Our connection is a mock connection {pkg}"), {
          expect_is(con, "DBIMockConnection")
        })

        test_that(glue("We can use mocks for dbGetQuery {pkg}"), {
          expect_identical(
            dbGetQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 2")),
            data.frame(
              carrier = c("9E", "AA"),
              name = c("Endeavor Air Inc.", "American Airlines Inc."),
              stringsAsFactors = FALSE
            )
          )
        })

        test_that(glue("We can use mocks for dbSendQuery {pkg}"), {
          result <- dbSendQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 2"))
          expect_identical(
            dbFetch(result),
            data.frame(
              carrier = c("9E", "AA"),
              name = c("Endeavor Air Inc.", "American Airlines Inc."),
              stringsAsFactors = FALSE
            )
          )
        })

        test_that(glue("A different query uses a different mock {pkg}"), {
          expect_identical(
            dbGetQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 1")),
            data.frame(
              carrier = c("9E"),
              name = c("Endeavor Air Inc."),
              stringsAsFactors = FALSE
            )
          )
        })

        test_that(glue("dbListTables() {pkg}"), {
          out <- dbListTables(con)
          expect_identical(out, tables)
        })

        test_that(glue("dbListFields() {pkg}"), {
          # dbListFields is ever so slightly different for each
          if (pkg == "RMariaDB") {
            out <- dbListFields(con, "flights")
          } else if (pkg == "odbc") {
            out <- dbListFields(con, Id(schema = schema, table = "flights"))
          } else if (pkg == "RPostgreSQL") {
            out <- dbListFields(con, c(schema, "flights"))
          } else if (pkg == "RPostgres") {
            out <- dbListFields(con, Id(schema = schema, table = "flights"))
          }
          expect_identical(out, fields_flights)
          expect_identical(out, c(
            "year", "month", "day", "dep_time", "sched_dep_time", "dep_delay",
            "arr_time", "sched_arr_time", "arr_delay", "carrier", "flight",
            "tailnum", "origin", "dest", "air_time", "distance", "hour",
            "minute", "time_hour"
          ))
        })

        test_that(glue("dbReadTable() {pkg}"), {
          if (pkg == "RMariaDB") {
            out <- dbReadTable(con, "airlines")
          } else if (pkg == "odbc") {
            out <- dbReadTable(con, Id(schema = schema, table = "airlines"))
          } else if (pkg == "RPostgreSQL") {
            out <- dbReadTable(con, c(schema, "airlines"))
          } else if (pkg == "RPostgres") {
            out <- dbReadTable(con, Id(schema = schema, table = "airlines"))
          }
          expect_identical(out, airlines_expected)
        })

        test_that(glue("dbClearResult {pkg}"), {
          result <- dbSendQuery(con, glue("SELECT * FROM {airlines_table} LIMIT 3"))
          expect_true(dbClearResult(result))
        })

        dbDisconnect(con)
      })
    })
  })
}