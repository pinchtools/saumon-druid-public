SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data (Community Edition)';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: vector; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA public;


--
-- Name: EXTENSION vector; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION vector IS 'vector data type and ivfflat and hnsw access methods';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: _compressed_hypertable_2; Type: TABLE; Schema: _timescaledb_internal; Owner: -
--

CREATE TABLE _timescaledb_internal._compressed_hypertable_2 (
);


--
-- Name: agent_version_llm_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_version_llm_models (
    id bigint NOT NULL,
    agent_version_id bigint NOT NULL,
    llm_model_id bigint NOT NULL,
    priority integer DEFAULT 1 NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: agent_version_llm_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_version_llm_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_version_llm_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_version_llm_models_id_seq OWNED BY public.agent_version_llm_models.id;


--
-- Name: agent_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agent_versions (
    id bigint NOT NULL,
    agent_id bigint NOT NULL,
    instructions jsonb,
    hyperparams jsonb,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    tools jsonb DEFAULT '[]'::jsonb NOT NULL
);


--
-- Name: agent_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agent_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agent_versions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agent_versions_id_seq OWNED BY public.agent_versions.id;


--
-- Name: agents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.agents (
    id bigint NOT NULL,
    name character varying NOT NULL,
    normalized_name character varying NOT NULL,
    description text,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    current_agent_version_id bigint
);


--
-- Name: agents_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.agents_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: agents_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.agents_id_seq OWNED BY public.agents.id;


--
-- Name: an_bodies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_bodies (
    id bigint NOT NULL,
    an_body_type_id bigint NOT NULL,
    uid character varying NOT NULL,
    label character varying,
    label_abbr character varying,
    label_code character varying,
    start_date timestamp(6) without time zone,
    end_date timestamp(6) without time zone,
    deliver_date timestamp(6) without time zone,
    chamber character varying,
    regime character varying,
    legislature character varying,
    number character varying,
    province character varying,
    department_code character varying,
    parent_id bigint,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: an_bodies_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_bodies_countries (
    an_body_id bigint NOT NULL,
    an_country_id bigint NOT NULL
);


--
-- Name: an_bodies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_bodies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_bodies_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_bodies_id_seq OWNED BY public.an_bodies.id;


--
-- Name: an_body_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_body_types (
    id bigint NOT NULL,
    code character varying,
    unique_per_date boolean DEFAULT false NOT NULL,
    single_assignment_per_actor boolean DEFAULT false NOT NULL,
    external boolean DEFAULT false NOT NULL,
    trans_legislature boolean DEFAULT false NOT NULL,
    local boolean DEFAULT false NOT NULL,
    has_substitute boolean DEFAULT false NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    institution character varying,
    "group" character varying,
    selection character varying,
    hierarchy_level integer
);


--
-- Name: an_body_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_body_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_body_types_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_body_types_id_seq OWNED BY public.an_body_types.id;


--
-- Name: an_corrections; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_corrections (
    id uuid DEFAULT uuidv7() NOT NULL,
    correctable_type character varying NOT NULL,
    correctable_id bigint NOT NULL,
    correction_changes jsonb DEFAULT '{}'::jsonb NOT NULL,
    reason character varying NOT NULL,
    correction_type character varying DEFAULT 'automatic'::character varying NOT NULL,
    session_id character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    CONSTRAINT check_correctable_type CHECK (((correctable_type)::text = ANY (ARRAY[('An::Stakeholder'::character varying)::text, ('An::Term'::character varying)::text, ('An::Body'::character varying)::text])))
);


--
-- Name: an_countries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_countries (
    id bigint NOT NULL,
    uid character varying NOT NULL,
    name character varying NOT NULL,
    insee_code character varying,
    insee_name character varying,
    iso_code character varying,
    active boolean DEFAULT true NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: an_countries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_countries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_countries_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_countries_id_seq OWNED BY public.an_countries.id;


--
-- Name: an_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_searches (
    id uuid DEFAULT uuidv7() NOT NULL,
    searchable_type character varying NOT NULL,
    searchable_id bigint NOT NULL,
    fts tsvector,
    trigram text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    embedding public.vector(1024)
);


--
-- Name: an_stakeholder_addresses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_stakeholder_addresses (
    id bigint NOT NULL,
    an_stakeholder_id bigint NOT NULL,
    uid character varying NOT NULL,
    address_1 character varying,
    address_2 character varying,
    street_name character varying,
    street_number character varying,
    post_code character varying,
    city character varying,
    weight integer,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    address_type character varying
);


--
-- Name: an_stakeholder_addresses_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_stakeholder_addresses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_stakeholder_addresses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_stakeholder_addresses_id_seq OWNED BY public.an_stakeholder_addresses.id;


--
-- Name: an_stakeholders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_stakeholders (
    id bigint NOT NULL,
    uid character varying NOT NULL,
    civility character varying,
    first_name character varying,
    last_name character varying,
    birth_date date,
    birth_city character varying,
    birth_province character varying,
    death_date date,
    occupation character varying,
    occupation_category character varying,
    occupation_family character varying,
    emails character varying[] DEFAULT '{}'::character varying[],
    urls character varying[] DEFAULT '{}'::character varying[],
    phone_numbers character varying[] DEFAULT '{}'::character varying[],
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    birth_country character varying,
    gender character varying
);


--
-- Name: an_stakeholders_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_stakeholders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_stakeholders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_stakeholders_id_seq OWNED BY public.an_stakeholders.id;


--
-- Name: an_substitutes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_substitutes (
    id bigint NOT NULL,
    an_term_id bigint NOT NULL,
    an_stakeholder_id bigint NOT NULL,
    start_date timestamp(6) without time zone,
    end_date timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: an_substitutes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_substitutes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_substitutes_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_substitutes_id_seq OWNED BY public.an_substitutes.id;


--
-- Name: an_terms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.an_terms (
    id bigint NOT NULL,
    an_stakeholder_id bigint NOT NULL,
    an_body_id bigint NOT NULL,
    constituency_id bigint,
    deputy_term_id bigint,
    uid character varying NOT NULL,
    legislature character varying,
    start_date timestamp(6) without time zone,
    end_date timestamp(6) without time zone,
    publish_date timestamp(6) without time zone,
    assumption_date timestamp(6) without time zone,
    role_rank integer,
    main boolean DEFAULT false NOT NULL,
    origin character varying,
    end_reason character varying,
    seat character varying,
    collaborators character varying[] DEFAULT '{}'::character varying[],
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    capacity character varying,
    label character varying(800)
);


--
-- Name: an_terms_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.an_terms_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: an_terms_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.an_terms_id_seq OWNED BY public.an_terms.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.events (
    id uuid DEFAULT uuidv7() NOT NULL,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    category character varying NOT NULL,
    action character varying NOT NULL,
    severity character varying DEFAULT 'info'::character varying NOT NULL,
    eventable_type character varying,
    eventable_id bigint,
    actor_id bigint,
    actor_type character varying,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    session_id uuid,
    request_id character varying,
    job_id character varying
);


--
-- Name: llm_models; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.llm_models (
    id bigint NOT NULL,
    name character varying NOT NULL,
    external_id character varying NOT NULL,
    family character varying NOT NULL,
    provider character varying NOT NULL,
    tier character varying,
    categories jsonb DEFAULT '[]'::jsonb,
    context_window integer,
    output_size integer,
    capabilities jsonb DEFAULT '[]'::jsonb,
    knowledge_cutoff date,
    input_cost numeric(10,6),
    output_cost numeric(10,6),
    available boolean DEFAULT true,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    free boolean DEFAULT false,
    supported_params jsonb DEFAULT '[]'::jsonb,
    CONSTRAINT valid_tier CHECK (((tier)::text = ANY (ARRAY[('tiny'::character varying)::text, ('small'::character varying)::text, ('medium'::character varying)::text, ('strong'::character varying)::text, ('top'::character varying)::text])))
);


--
-- Name: llm_models_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.llm_models_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: llm_models_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.llm_models_id_seq OWNED BY public.llm_models.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: agent_version_llm_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_version_llm_models ALTER COLUMN id SET DEFAULT nextval('public.agent_version_llm_models_id_seq'::regclass);


--
-- Name: agent_versions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_versions ALTER COLUMN id SET DEFAULT nextval('public.agent_versions_id_seq'::regclass);


--
-- Name: agents id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents ALTER COLUMN id SET DEFAULT nextval('public.agents_id_seq'::regclass);


--
-- Name: an_bodies id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies ALTER COLUMN id SET DEFAULT nextval('public.an_bodies_id_seq'::regclass);


--
-- Name: an_body_types id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_body_types ALTER COLUMN id SET DEFAULT nextval('public.an_body_types_id_seq'::regclass);


--
-- Name: an_countries id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_countries ALTER COLUMN id SET DEFAULT nextval('public.an_countries_id_seq'::regclass);


--
-- Name: an_stakeholder_addresses id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_stakeholder_addresses ALTER COLUMN id SET DEFAULT nextval('public.an_stakeholder_addresses_id_seq'::regclass);


--
-- Name: an_stakeholders id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_stakeholders ALTER COLUMN id SET DEFAULT nextval('public.an_stakeholders_id_seq'::regclass);


--
-- Name: an_substitutes id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_substitutes ALTER COLUMN id SET DEFAULT nextval('public.an_substitutes_id_seq'::regclass);


--
-- Name: an_terms id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms ALTER COLUMN id SET DEFAULT nextval('public.an_terms_id_seq'::regclass);


--
-- Name: llm_models id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_models ALTER COLUMN id SET DEFAULT nextval('public.llm_models_id_seq'::regclass);


--
-- Name: agent_version_llm_models agent_version_llm_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_version_llm_models
    ADD CONSTRAINT agent_version_llm_models_pkey PRIMARY KEY (id);


--
-- Name: agent_versions agent_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_versions
    ADD CONSTRAINT agent_versions_pkey PRIMARY KEY (id);


--
-- Name: agents agents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT agents_pkey PRIMARY KEY (id);


--
-- Name: an_bodies an_bodies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies
    ADD CONSTRAINT an_bodies_pkey PRIMARY KEY (id);


--
-- Name: an_body_types an_body_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_body_types
    ADD CONSTRAINT an_body_types_pkey PRIMARY KEY (id);


--
-- Name: an_corrections an_corrections_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_corrections
    ADD CONSTRAINT an_corrections_pkey PRIMARY KEY (id);


--
-- Name: an_countries an_countries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_countries
    ADD CONSTRAINT an_countries_pkey PRIMARY KEY (id);


--
-- Name: an_searches an_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_searches
    ADD CONSTRAINT an_searches_pkey PRIMARY KEY (id);


--
-- Name: an_stakeholder_addresses an_stakeholder_addresses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_stakeholder_addresses
    ADD CONSTRAINT an_stakeholder_addresses_pkey PRIMARY KEY (id);


--
-- Name: an_stakeholders an_stakeholders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_stakeholders
    ADD CONSTRAINT an_stakeholders_pkey PRIMARY KEY (id);


--
-- Name: an_substitutes an_substitutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_substitutes
    ADD CONSTRAINT an_substitutes_pkey PRIMARY KEY (id);


--
-- Name: an_terms an_terms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms
    ADD CONSTRAINT an_terms_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: llm_models llm_models_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.llm_models
    ADD CONSTRAINT llm_models_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: events_created_at_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX events_created_at_idx ON public.events USING btree (created_at DESC);


--
-- Name: idx_corrections_on_correctable_and_time; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_corrections_on_correctable_and_time ON public.an_corrections USING btree (correctable_type, correctable_id, created_at);


--
-- Name: idx_on_agent_version_id_llm_model_id_6916d77c45; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_agent_version_id_llm_model_id_6916d77c45 ON public.agent_version_llm_models USING btree (agent_version_id, llm_model_id);


--
-- Name: idx_on_agent_version_id_priority_43756bb370; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_on_agent_version_id_priority_43756bb370 ON public.agent_version_llm_models USING btree (agent_version_id, priority);


--
-- Name: index_agent_version_llm_models_on_agent_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_version_llm_models_on_agent_version_id ON public.agent_version_llm_models USING btree (agent_version_id);


--
-- Name: index_agent_version_llm_models_on_llm_model_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_version_llm_models_on_llm_model_id ON public.agent_version_llm_models USING btree (llm_model_id);


--
-- Name: index_agent_versions_on_agent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agent_versions_on_agent_id ON public.agent_versions USING btree (agent_id);


--
-- Name: index_agent_versions_on_agent_id_and_version; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agent_versions_on_agent_id_and_version ON public.agent_versions USING btree (agent_id, version);


--
-- Name: index_agents_on_current_agent_version_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_agents_on_current_agent_version_id ON public.agents USING btree (current_agent_version_id);


--
-- Name: index_agents_on_normalized_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_agents_on_normalized_name ON public.agents USING btree (normalized_name);


--
-- Name: index_an_bodies_countries_on_an_body_id_and_an_country_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_bodies_countries_on_an_body_id_and_an_country_id ON public.an_bodies_countries USING btree (an_body_id, an_country_id);


--
-- Name: index_an_bodies_on_an_body_type_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_bodies_on_an_body_type_id ON public.an_bodies USING btree (an_body_type_id);


--
-- Name: index_an_bodies_on_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_bodies_on_parent_id ON public.an_bodies USING btree (parent_id);


--
-- Name: index_an_bodies_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_bodies_on_uid ON public.an_bodies USING btree (uid);


--
-- Name: index_an_body_types_on_code; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_body_types_on_code ON public.an_body_types USING btree (code);


--
-- Name: index_an_corrections_on_correctable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_corrections_on_correctable ON public.an_corrections USING btree (correctable_type, correctable_id);


--
-- Name: index_an_corrections_on_correction_changes; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_corrections_on_correction_changes ON public.an_corrections USING gin (correction_changes);


--
-- Name: index_an_corrections_on_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_corrections_on_created_at ON public.an_corrections USING btree (created_at);


--
-- Name: index_an_corrections_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_corrections_on_session_id ON public.an_corrections USING btree (session_id);


--
-- Name: index_an_countries_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_countries_on_name ON public.an_countries USING btree (name);


--
-- Name: index_an_countries_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_countries_on_uid ON public.an_countries USING btree (uid);


--
-- Name: index_an_searches_on_embedding; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_searches_on_embedding ON public.an_searches USING hnsw (embedding public.vector_cosine_ops) WITH (m='24', ef_construction='300');


--
-- Name: index_an_searches_on_fts; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_searches_on_fts ON public.an_searches USING gin (fts);


--
-- Name: index_an_searches_on_searchable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_searches_on_searchable ON public.an_searches USING btree (searchable_type, searchable_id);


--
-- Name: index_an_searches_on_searchable_type_and_searchable_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_searches_on_searchable_type_and_searchable_id ON public.an_searches USING btree (searchable_type, searchable_id);


--
-- Name: index_an_searches_on_trigram; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_searches_on_trigram ON public.an_searches USING gin (trigram public.gin_trgm_ops);


--
-- Name: index_an_stakeholder_addresses_on_an_stakeholder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholder_addresses_on_an_stakeholder_id ON public.an_stakeholder_addresses USING btree (an_stakeholder_id);


--
-- Name: index_an_stakeholder_addresses_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_stakeholder_addresses_on_uid ON public.an_stakeholder_addresses USING btree (uid);


--
-- Name: index_an_stakeholders_on_birth_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_birth_date ON public.an_stakeholders USING btree (birth_date);


--
-- Name: index_an_stakeholders_on_first_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_first_name ON public.an_stakeholders USING btree (first_name);


--
-- Name: index_an_stakeholders_on_last_name; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_last_name ON public.an_stakeholders USING btree (last_name);


--
-- Name: index_an_stakeholders_on_occupation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_occupation ON public.an_stakeholders USING btree (occupation);


--
-- Name: index_an_stakeholders_on_occupation_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_occupation_category ON public.an_stakeholders USING btree (occupation_category);


--
-- Name: index_an_stakeholders_on_occupation_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_stakeholders_on_occupation_family ON public.an_stakeholders USING btree (occupation_family);


--
-- Name: index_an_stakeholders_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_stakeholders_on_uid ON public.an_stakeholders USING btree (uid);


--
-- Name: index_an_substitutes_on_an_stakeholder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_substitutes_on_an_stakeholder_id ON public.an_substitutes USING btree (an_stakeholder_id);


--
-- Name: index_an_substitutes_on_an_term_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_substitutes_on_an_term_id ON public.an_substitutes USING btree (an_term_id);


--
-- Name: index_an_terms_by_stakeholder_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_by_stakeholder_active ON public.an_terms USING btree (an_stakeholder_id, end_date, start_date) WHERE ((start_date IS NOT NULL) AND (end_date IS NULL));


--
-- Name: index_an_terms_by_stakeholder_past; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_by_stakeholder_past ON public.an_terms USING btree (an_stakeholder_id, start_date, end_date) WHERE ((start_date IS NOT NULL) AND (end_date IS NOT NULL));


--
-- Name: index_an_terms_on_an_body_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_on_an_body_id ON public.an_terms USING btree (an_body_id);


--
-- Name: index_an_terms_on_an_stakeholder_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_on_an_stakeholder_id ON public.an_terms USING btree (an_stakeholder_id);


--
-- Name: index_an_terms_on_constituency_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_on_constituency_id ON public.an_terms USING btree (constituency_id);


--
-- Name: index_an_terms_on_deputy_term_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_an_terms_on_deputy_term_id ON public.an_terms USING btree (deputy_term_id);


--
-- Name: index_an_terms_on_uid; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_an_terms_on_uid ON public.an_terms USING btree (uid);


--
-- Name: index_events_on_category_and_action_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_category_and_action_and_created_at ON public.events USING btree (category, action, created_at);


--
-- Name: index_events_on_eventable_type_and_eventable_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_eventable_type_and_eventable_id_and_created_at ON public.events USING btree (eventable_type, eventable_id, created_at);


--
-- Name: index_events_on_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_events_on_id_and_created_at ON public.events USING btree (id, created_at);


--
-- Name: index_events_on_payload; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_payload ON public.events USING gin (payload);


--
-- Name: index_events_on_session_id_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_session_id_and_created_at ON public.events USING btree (session_id, created_at);


--
-- Name: index_events_on_severity_and_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_events_on_severity_and_created_at ON public.events USING btree (severity, created_at) WHERE ((severity)::text = ANY (ARRAY[('warn'::character varying)::text, ('error'::character varying)::text]));


--
-- Name: index_llm_models_on_external_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_llm_models_on_external_id ON public.llm_models USING btree (external_id);


--
-- Name: index_llm_models_on_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_models_on_family ON public.llm_models USING btree (family);


--
-- Name: index_llm_models_on_tier; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_llm_models_on_tier ON public.llm_models USING btree (tier);


--
-- Name: index_terms_on_dates; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_terms_on_dates ON public.an_terms USING btree (start_date, end_date);


--
-- Name: an_bodies_countries fk_rails_1069b87944; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies_countries
    ADD CONSTRAINT fk_rails_1069b87944 FOREIGN KEY (an_country_id) REFERENCES public.an_countries(id) ON DELETE CASCADE;


--
-- Name: agents fk_rails_43cfc1a7df; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agents
    ADD CONSTRAINT fk_rails_43cfc1a7df FOREIGN KEY (current_agent_version_id) REFERENCES public.agent_versions(id);


--
-- Name: agent_version_llm_models fk_rails_473fade9d8; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_version_llm_models
    ADD CONSTRAINT fk_rails_473fade9d8 FOREIGN KEY (agent_version_id) REFERENCES public.agent_versions(id);


--
-- Name: an_bodies fk_rails_55975c093c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies
    ADD CONSTRAINT fk_rails_55975c093c FOREIGN KEY (parent_id) REFERENCES public.an_bodies(id);


--
-- Name: an_terms fk_rails_712f035a39; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms
    ADD CONSTRAINT fk_rails_712f035a39 FOREIGN KEY (an_body_id) REFERENCES public.an_bodies(id);


--
-- Name: an_terms fk_rails_7738549360; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms
    ADD CONSTRAINT fk_rails_7738549360 FOREIGN KEY (constituency_id) REFERENCES public.an_bodies(id);


--
-- Name: an_bodies_countries fk_rails_7f0d5352f5; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies_countries
    ADD CONSTRAINT fk_rails_7f0d5352f5 FOREIGN KEY (an_body_id) REFERENCES public.an_bodies(id) ON DELETE CASCADE;


--
-- Name: an_substitutes fk_rails_800631579a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_substitutes
    ADD CONSTRAINT fk_rails_800631579a FOREIGN KEY (an_term_id) REFERENCES public.an_terms(id);


--
-- Name: an_terms fk_rails_8ae8292616; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms
    ADD CONSTRAINT fk_rails_8ae8292616 FOREIGN KEY (deputy_term_id) REFERENCES public.an_terms(id);


--
-- Name: agent_versions fk_rails_91d862e032; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_versions
    ADD CONSTRAINT fk_rails_91d862e032 FOREIGN KEY (agent_id) REFERENCES public.agents(id);


--
-- Name: agent_version_llm_models fk_rails_d6b25ae53d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.agent_version_llm_models
    ADD CONSTRAINT fk_rails_d6b25ae53d FOREIGN KEY (llm_model_id) REFERENCES public.llm_models(id);


--
-- Name: an_bodies fk_rails_dee7249e2e; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_bodies
    ADD CONSTRAINT fk_rails_dee7249e2e FOREIGN KEY (an_body_type_id) REFERENCES public.an_body_types(id);


--
-- Name: an_substitutes fk_rails_e74e7ea671; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_substitutes
    ADD CONSTRAINT fk_rails_e74e7ea671 FOREIGN KEY (an_stakeholder_id) REFERENCES public.an_stakeholders(id);


--
-- Name: an_terms fk_rails_f0db6e0b0c; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_terms
    ADD CONSTRAINT fk_rails_f0db6e0b0c FOREIGN KEY (an_stakeholder_id) REFERENCES public.an_stakeholders(id);


--
-- Name: an_stakeholder_addresses fk_rails_f1f5b0f5a7; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.an_stakeholder_addresses
    ADD CONSTRAINT fk_rails_f1f5b0f5a7 FOREIGN KEY (an_stakeholder_id) REFERENCES public.an_stakeholders(id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20251226135247'),
('20251214102158'),
('20251213152738'),
('20251212100104'),
('20251211151254'),
('20251211150413'),
('20251208101235'),
('20251208094814'),
('20251207155619'),
('20251207151443'),
('20251202125839'),
('20251202074817'),
('20251202071609'),
('20251127112234'),
('20251124095002'),
('20251123140318'),
('20251123105631'),
('20251117092625'),
('20251117073420'),
('20251115154818'),
('20251115133903'),
('20251115132412'),
('20251115104054'),
('20251114133302'),
('20251112101635'),
('20251111134753'),
('20251022122154'),
('20251018115915'),
('20251017143720'),
('20251017091957'),
('20251016125841'),
('20251012133659'),
('20251010082054'),
('20251010073208'),
('20251007060832'),
('20251006143641'),
('20251006141635'),
('20251006132924'),
('20251006125353');

