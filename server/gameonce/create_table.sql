use  sutraGameDB;

drop table userBaseData;

create table userBaseData
    (
    uuid char(64) not null primary key,
    registerTime long not null,
    jingtuGroup char(64) not null,
	lotusNum int not null,
	phoneType char(32) default '',
	userData varchar(32),
	unique(uuid)
	);

	
	
	

drop table userUpdateData;

create table userUpdateData
    (
    uuid char(64) not null primary key,
	incenseLastTime int not null,
	loginLastTime int not null,
	sutraLastTime int not null,
	signNum int not null,
	censerNum int not null,
	sutraNum int not null,
	fohaoNum int not null,
	signRank int not null,
	censerRank int not null,
	sutraRank int not null,
	totalRank int not null,
	unique(uuid)
	);
	
	
	
	
	drop table monthCollect;

create table monthCollect
	(
	uuid char(64) not null  primary key,
	signLine int not null,
	month int not null primary key,
	fohaoGroup varchar(64),
	fohaoMonthNum int not null,
	);
