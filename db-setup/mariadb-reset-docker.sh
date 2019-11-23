# reset maraidb databases in docker

docker exec dbtest-mariadb mysql -pr2N5y7V* -e "DROP DATABASE IF EXISTS nycflights;"
docker exec dbtest-mariadb mysql -pr2N5y7V* -e "CREATE DATABASE nycflights;"
docker exec dbtest-mariadb mysql -pr2N5y7V* -e "CREATE USER IF NOT EXISTS travis@'%'; GRANT ALL ON *.* TO travis@'%'; FLUSH PRIVILEGES;"
