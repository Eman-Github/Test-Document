-- Drop table

-- DROP TABLE public.document_schema_details

CREATE TABLE public.document_schema_details (
	document_name varchar NOT NULL,
	environment varchar NOT NULL,
	deployment_timestamp timestamptz NULL DEFAULT now(),
	schema_id varchar NOT NULL,
	document_schema_url varchar NULL,
	document_sample_url varchar NULL,
	tl_version int4 NOT NULL,
	release_version int4 NOT NULL,
	depolyment_version float4 NOT NULL
);
