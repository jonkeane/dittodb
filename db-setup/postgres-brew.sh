rm -rf /usr/local/var/postgres
# for odbc tests, we need to also install the odbc drivers
brew install psqlodbc
# this shouldn't be necessary, but might be for GH actions now?
brew link --overwrite postgresql
cat <<EOT >> /usr/local/etc/odbcinst.ini
[PostgreSQL Unicode]
Description     = PostgreSQL ODBC driver (Unicode 9.2)
Driver          = /usr/local/lib/psqlodbcw.so
Debug           = 0
CommLog         = 1
UsageCount      = 1
EOT
initdb /usr/local/var/postgres
pg_ctl -D /usr/local/var/postgres start
/usr/local/opt/postgres/bin/createuser -s postgres
sleep 2
