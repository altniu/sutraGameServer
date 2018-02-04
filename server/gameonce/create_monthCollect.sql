use sutraGameDB;

drop table monthCollect;

create table monthCollect
	(
	uuid char(64) not null  primary key,
	signLine int not null,
	month int not null,
	fohaoGroup varchar(64),
	unique(uuid)
	);
