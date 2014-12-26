CREATE TABLE stat_organizations
(
	id serial not null primary key,
	name text not null UNIQUE,
	descr text not null

);


CREATE TABLE stat_surveys
(
	id serial not null primary key,
	name text not null,
	descr text,
	survey_date date not null default 'now',
	organization_id int references stat_organizations,
	organization text not null
);


CREATE TABLE stat_indicators
(
	id serial not null primary key,
	name text not null UNIQUE,
	descr text
);


CREATE TABLE stat_indicators_adm_units
(
	id serial not null primary key,
	adm_unit_id int not null references adm_units,
	indicator_id int not null references stat_indicators,
	survey_id int not null references stat_surveys,
	value int not null,
	UNIQUE(adm_unit_id, indicator_id, survey_id)
);



INSERT INTO stat_organizations VALUES
(
	1,
	'НСИ',
	'Национален статистически институт'	
);
INSERT INTO stat_surveys VALUES
(
	1,
	'17-то преброяване на населението и жилищния фонд 2011',
	'17-то преброяване на населението и жилищния фонд 2011',
	'2011-02-01',
	1,
	'НСИ'
);

INSERT INTO stat_indicators VALUES (default, 'pop_total', 'pop_total');
INSERT INTO stat_indicators VALUES (default, 'pop_age_0_4', 'pop_age_0_4');
INSERT INTO stat_indicators VALUES (default, 'pop_age_5_9', 'pop_age_5_9');
INSERT INTO stat_indicators VALUES (default, 'pop_age_10_14', 'pop_age_10_14');
INSERT INTO stat_indicators VALUES (default, 'pop_age_15_19', 'pop_age_15_19');
INSERT INTO stat_indicators VALUES (default, 'pop_age_20_24', 'pop_age_20_24');
INSERT INTO stat_indicators VALUES (default, 'pop_age_25_29', 'pop_age_25_29');
INSERT INTO stat_indicators VALUES (default, 'pop_age_30_34', 'pop_age_30_34');
INSERT INTO stat_indicators VALUES (default, 'pop_age_35_39', 'pop_age_35_39');
INSERT INTO stat_indicators VALUES (default, 'pop_age_45_49', 'pop_age_45_49');
INSERT INTO stat_indicators VALUES (default, 'pop_age_40_44', 'pop_age_40_44');
INSERT INTO stat_indicators VALUES (default, 'pop_age_50_54', 'pop_age_50_54');
INSERT INTO stat_indicators VALUES (default, 'pop_age_55_59', 'pop_age_55_59');
INSERT INTO stat_indicators VALUES (default, 'pop_age_60_64', 'pop_age_60_64');
INSERT INTO stat_indicators VALUES (default, 'pop_age_65_69', 'pop_age_65_69');
INSERT INTO stat_indicators VALUES (default, 'pop_age_70_74', 'pop_age_70_74');
INSERT INTO stat_indicators VALUES (default, 'pop_age_75_79', 'pop_age_75_79');
INSERT INTO stat_indicators VALUES (default, 'pop_age_80_84', 'pop_age_80_84');
INSERT INTO stat_indicators VALUES (default, 'pop_age_85', 'pop_age_85');
