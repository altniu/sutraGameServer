mysqldump -u root -proot sutraGameDB | gzip -> /root/sutraGameServer/dbbak_mysql/`date +%Y%m%d`.sql.gz
find /root/sutraGameServer/dbbak_mysql/ -name '*[1-9].sql' -type f -mtime +7 -exec rm -rf {} \;
find /root/sutraGameServer/dbbak_mysql/ -name '*.sql' -type f -mtime +92 -exec rm -rf {} \;
