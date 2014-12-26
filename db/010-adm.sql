create table adm_types ( 
    id int not null primary key, 
    name text not null, 
    descr text not null
);

insert into adm_types values 
(1, 'town', 'town, city etc'), 
(2, 'monastery', 'monasteries'), 
(3, 'village', 'village'), 
(4, 'municipality', 'municipality'), 
('5', 'province', 'province'),
('6', 'region', 'region'),
('7', 'eu_region', 'eu_region'),
('8', 'country', 'country'),
('9', 'kmetstva', 'kmetstva')
;

create table institutions (
    id serial primary key,
    name text not null unique,
    descr text not null unique
);

create table adm_doc_types(
    id serial primary key,
    name text not null unique,
    descr text not null unique
);

create table adm_docs (
    id serial primary key,
    ekatte_id int not null unique,
    doc_type text not null, 
    doc_type_id int references adm_doc_types,
    doc_institution text not null,
    doc_institution_id int references institutions,
    doc_name text not null,
    doc_number text,
    doc_date date not null,
    doc_active_date date not null,
    state_gazette_publ text,
    state_gazette_date date
);


create table adm_units (
    id serial not null primary key, 
    parent_id int references adm_units,
    adm_type_id int not null references adm_types,
    doc_id int references adm_docs,  
    ekatte int,
    ekatte_name text unique,
    ekatte_category int,
    ekatte_altitude int,
    name text not null,
    int_name text not null
);


CREATE RECURSIVE VIEW adm_units_tree_by_id (id, ancestors, depth, cycle) AS (
    SELECT id, '{}'::integer[], 0, FALSE
    FROM adm_units 
    WHERE parent_id IS NULL
    UNION ALL
    SELECT
      n.id, t.ancestors || n.parent_id, t.depth + 1, n.parent_id = ANY(t.ancestors)
    FROM adm_units n, adm_units_tree_by_id t
    WHERE n.parent_id = t.id
        AND NOT t.cycle
);
