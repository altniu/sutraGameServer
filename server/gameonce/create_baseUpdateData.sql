use  sutraGameDB;
create table userUpdateData
    (
    uuid char(64) not null primary key,
	incenseLastTime int not null,
	signNum int not null,
	censerNum int not null,
	sutraNum int not null,
	signRank int not null,
	censerRank int not null,
	sutraRank int not null,
	totalRank int not null,
	unique(uuid)
	);

	
	
	
