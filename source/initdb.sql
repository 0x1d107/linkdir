-- public.links definition

-- Drop table

-- DROP TABLE public.links;

CREATE TABLE public.links (
	id SERIAL NOT NULL ,
	"name" varchar NULL,
	url varchar NULL,
	CONSTRAINT links_pk PRIMARY KEY (id)
);
-- public.permissions definition

-- Drop table

-- DROP TABLE public.permissions;

CREATE TABLE public.permissions (
	tree_id int4 NOT NULL,
	user_id int4 NOT NULL,
	permission_byte int4 NULL,
	CONSTRAINT permissions_pk PRIMARY KEY (tree_id, user_id)
);



-- public.tag_link definition


-- public.tag_link definition

-- Drop table

-- DROP TABLE public.tag_link;

CREATE TABLE public.tag_link (
	tag_id serial NOT NULL,
	link_id int4 NULL,
	CONSTRAINT tag_link_un UNIQUE (tag_id, link_id)
);



-- public.tags definition

-- Drop table
DROP TABLE public.tags;

CREATE TABLE public.tags (
	id SERIAL NOT NULL,
	"name" varchar NULL,
	left_tag int4 NULL,
	right_tag int4 NULL,
	"level" int4 NULL,
	tree_id int4 NULL,
	CONSTRAINT tags_pk PRIMARY KEY (id),
	CONSTRAINT tags_un UNIQUE (name)
);
-- public.users definition

-- Drop table

-- DROP TABLE public.users;

CREATE TABLE public.users (
	id SERIAL NOT NULL,
	login varchar NULL,
	hash varchar NULL,
	email varchar NULL,
	CONSTRAINT users_pk PRIMARY KEY (id)
);

-- public.permissions foreign keys

ALTER TABLE public.permissions ADD CONSTRAINT permissions_fk FOREIGN KEY (user_id) REFERENCES public.users(id);
-- public.tag_link foreign keys

ALTER TABLE public.tag_link ADD CONSTRAINT link_fk FOREIGN KEY (link_id) REFERENCES public.links(id) ON DELETE CASCADE;
ALTER TABLE public.tag_link ADD CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

