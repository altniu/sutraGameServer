drop table userBaseData;
create table userBaseData
    (
    uuid char(64) not null auto_increment primary key,
    registerTime long not null,
    signNum int not null,
    censerNum int not null,
    sutraNum int not null,
    jingtuGroup char(64) not null,
	lotusNum int not null,
	phoneType char(32) default '',
	userData varchar(32),
	unique(uuid)
	);

	
	
	