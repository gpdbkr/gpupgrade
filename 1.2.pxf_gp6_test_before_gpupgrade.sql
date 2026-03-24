--1.2.1 pxf write/read test

DROP TABLE IF EXISTS public.pxf_test_hist ;

CREATE TABLE public.pxf_test_hist (
    id INT,
    date_col DATE,
    a TEXT
)
WITH (appendonly=true, compresstype=zstd, compresslevel=7)
DISTRIBUTED BY (id)
PARTITION BY RANGE (date_col)
(
   --START ('2025-01-01') END ('2025-01-10') EVERY (INTERVAL '1 day')
   partition p20260101 start('2026-01-01') end ('2026-01-02') ,
   partition p20260102 start('2026-01-02') end ('2026-01-03') ,
   partition p20260103 start('2026-01-03') end ('2026-01-04') ,
   partition p20260104 start('2026-01-04') end ('2026-01-05') ,
   partition p20260105 start('2026-01-05') end ('2026-01-06') ,
   partition p20260106 start('2026-01-06') end ('2026-01-07') ,
   partition p20260107 start('2026-01-07') end ('2026-01-08') ,
   partition p20260108 start('2026-01-08') end ('2026-01-09') ,
   partition p20260109 start('2026-01-09') end ('2026-01-10') ,
   partition p20260110 start('2026-01-10') end ('2026-01-11') 
) 
;

INSERT INTO public.pxf_test_hist
SELECT i id
     , '2026-01-01'::date + i AS date_col 
     , i::TEXT a 
FROM generate_series(0, 9) i 
;

DROP EXTERNAL TABLE if EXISTS public.ext_w_pxf_test_hist_20260101 ;

CREATE WRITABLE EXTERNAL TABLE public.ext_w_pxf_test_hist_20260101 (LIKE public.pxf_test_hist) 
LOCATION('pxf://data/pxf_test_hist_20260101.parquet?PROFILE=s3:parquet&SERVER=minio')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_export')
ENCODING 'UTF8'
DISTRIBUTED BY (id)
;

INSERT INTO public.ext_w_pxf_test_hist_20260101
SELECT * FROM public.pxf_test_hist 
WHERE date_col = '2026-01-01'::date;

DROP EXTERNAL TABLE if EXISTS public.ext_r_pxf_test_hist_20260101;

CREATE READABLE EXTERNAL TABLE public.ext_r_pxf_test_hist_20260101 (LIKE pxf_test_hist) 
LOCATION('pxf://data/pxf_test_hist_20260101.parquet?PROFILE=s3:parquet&SERVER=minio')
FORMAT 'CUSTOM' (FORMATTER='pxfwritable_import')
ENCODING 'UTF8'
;

SELECT * FROM public.ext_r_pxf_test_hist_20260101;


SELECT t1.nspname, t2.relname, t2.relkind, t2.relstorage, t2.reloptions 
FROM  pg_namespace t1 
JOIN  pg_class t2 
ON    t1.oid = t2.relnamespace   
WHERE t1.nspname = 'public' 
AND   t2.relname LIKE 'pxf_test_hist%'
ORDER BY 1,2;
/*
nspname|relname                      |relkind|relstorage|reloptions                                         |
-------+-----------------------------+-------+----------+---------------------------------------------------+
public |pxf_test_hist                |r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260101|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260102|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260103|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260104|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260105|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260106|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260107|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260108|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260109|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260110|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
*/

SELECT * FROM public.pxf_test_hist
WHERE date_col >= '2026-01-01'
AND   date_col <= '2026-01-03'
ORDER BY 2;

/*
id|date_col  |a|
--+----------+-+
 0|2026-01-01|0|
 1|2026-01-02|1|
 2|2026-01-03|2|
 */
 
EXPLAIN 
SELECT * FROM public.pxf_test_hist
WHERE date_col >= '2026-01-01'
AND   date_col <= '2026-01-03';
/*
QUERY PLAN                                                                                                 |
-----------------------------------------------------------------------------------------------------------+
Gather Motion 4:1  (slice1; segments: 4)  (cost=0.00..431.00 rows=1 width=16)                              |
  ->  Sequence  (cost=0.00..431.00 rows=1 width=16)                                                        |
        ->  Partition Selector for pxf_test_hist (dynamic scan id: 1)  (cost=10.00..100.00 rows=25 width=4)|
              Partitions selected: 3 (out of 10)                                                           |
        ->  Dynamic Seq Scan on pxf_test_hist (dynamic scan id: 1)  (cost=0.00..431.00 rows=1 width=16)    |
              Filter: ((date_col >= '2026-01-01'::date) AND (date_col <= '2026-01-03'::date))              |
Optimizer: Pivotal Optimizer (GPORCA)                                                                      |
*/

ALTER TABLE public.pxf_test_hist 
EXCHANGE PARTITION p20260101
WITH TABLE public.ext_r_pxf_test_hist_20260101
WITHOUT VALIDATION;


SELECT t1.nspname, t2.relname, t2.relkind, t2.relstorage, t2.reloptions 
FROM  pg_namespace t1 
JOIN  pg_class t2 
ON    t1.oid = t2.relnamespace   
WHERE t1.nspname = 'public' 
AND   t2.relname LIKE 'pxf_test_hist%'
ORDER BY 1,2;
/*
nspname|relname                      |relkind|relstorage|reloptions                                         |
-------+-----------------------------+-------+----------+---------------------------------------------------+
public |pxf_test_hist                |r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260101|r      |x         |NULL                                               |
public |pxf_test_hist_1_prt_p20260102|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260103|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260104|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260105|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260106|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260107|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260108|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260109|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
public |pxf_test_hist_1_prt_p20260110|r      |a         |{appendonly=true,compresstype=zstd,compresslevel=7}|
*/

SELECT * FROM public.pxf_test_hist
WHERE date_col >= '2026-01-01'
AND   date_col <= '2026-01-03'
ORDER BY 2;

/*
id|date_col  |a|
--+----------+-+
 0|2026-01-01|0|
 1|2026-01-02|1|
 2|2026-01-03|2|
 */

EXPLAIN 
SELECT * FROM public.pxf_test_hist
WHERE date_col >= '2026-01-01'
AND   date_col <= '2026-01-03'
ORDER BY 2;

/*
QUERY PLAN                                                                                                |
----------------------------------------------------------------------------------------------------------+
Gather Motion 4:1  (slice1; segments: 4)  (cost=18334.48..18361.82 rows=10934 width=40)                   |
  Merge Key: pxf_test_hist_1_prt_p20260102.date_col                                                       |
  ->  Sort  (cost=18334.48..18361.82 rows=2734 width=40)                                                  |
        Sort Key: pxf_test_hist_1_prt_p20260102.date_col                                                  |
        ->  Append  (cost=0.00..17601.00 rows=2734 width=40)                                              |
              ->  Seq Scan on pxf_test_hist_1_prt_p20260102  (cost=0.00..800.50 rows=117 width=40)        |
                    Filter: ((date_col >= '2026-01-01'::date) AND (date_col <= '2026-01-03'::date))       |
              ->  Seq Scan on pxf_test_hist_1_prt_p20260103  (cost=0.00..800.50 rows=117 width=40)        |
                    Filter: ((date_col >= '2026-01-01'::date) AND (date_col <= '2026-01-03'::date))       |
              ->  External Scan on pxf_test_hist_1_prt_p20260101  (cost=0.00..16000.00 rows=2500 width=40)|
                    Filter: ((date_col >= '2026-01-01'::date) AND (date_col <= '2026-01-03'::date))       |
Optimizer: Postgres query optimizer                                                                       |
*/

