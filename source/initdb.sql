-- public.links definition

-- Drop table

-- DROP TABLE public.links;

CREATE TABLE public.links (
	id serial NOT NULL,
	"name" varchar NULL,
	url varchar NULL,
	summary varchar NULL,
	ts tsvector NULL GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, name::text), 'A'::"char") || setweight(to_tsvector('english'::regconfig, COALESCE(summary, ''::character varying)::text), 'B'::"char")) STORED,
	CONSTRAINT links_pk PRIMARY KEY (id)
);
-- public.permissions definition

-- Drop table

-- DROP TABLE public.permissions;

CREATE TABLE public.permissions (
	tree_id int4 NOT NULL,
	user_id int4 NOT NULL,
	permission_byte int4 NOT NULL,
	CONSTRAINT permissions_pk PRIMARY KEY (tree_id, user_id)
);



-- public.tag_link definition


-- public.tag_link definition

-- Drop table

-- DROP TABLE public.tag_link;

CREATE TABLE public.tag_link (
	tag_id serial NOT NULL,
	link_id int4 NOT NULL,
	CONSTRAINT tag_link_un UNIQUE (tag_id, link_id)
);



-- public.tags definition

-- Drop table
--DROP TABLE public.tags;

CREATE TABLE public.tags (
	id serial NOT NULL,
	"name" varchar NULL,
	left_tag int4 NULL,
	right_tag int4 NULL,
	"level" int4 NULL,
	tree_id int4 NULL,
	parent int4 NULL,
	summary varchar NULL,
	ts tsvector NULL GENERATED ALWAYS AS (setweight(to_tsvector('english'::regconfig, replace(name::text, '/'::text, ' '::text)), 'A'::"char") || setweight(to_tsvector('english'::regconfig, COALESCE(summary, ''::character varying)::text), 'B'::"char")) STORED,
	CONSTRAINT tags_pk PRIMARY KEY (id),
	CONSTRAINT tags_un UNIQUE (name)
);
-- public.users definition

-- Drop table

-- DROP TABLE public.users;

CREATE TABLE public.users (
	id SERIAL NOT NULL,
	login varchar NOT NULL,
	hash varchar NOT NULL,
	email varchar NOT NULL,
	CONSTRAINT users_pk PRIMARY KEY (id)
);

-- public.permissions foreign keys

ALTER TABLE public.permissions ADD CONSTRAINT permissions_fk FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;
-- public.tag_link foreign keys

ALTER TABLE public.tag_link ADD CONSTRAINT link_fk FOREIGN KEY (link_id) REFERENCES public.links(id) ON DELETE CASCADE;
ALTER TABLE public.tag_link ADD CONSTRAINT tag_fk FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;

CREATE INDEX link_ts ON public.links USING gin (ts);
CREATE INDEX tag_ts ON public.tags USING gin (ts);

-- DEFAULT VALUES
INSERT INTO public.users(id,login,hash,email) values (0,public,NULL,NULL);
INSERT INTO public.permissions(tree_id,user_id,permission_byte) VALUES (0,0,1);
