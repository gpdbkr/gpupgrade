--1.3. pxf write/read test for Greenplum 7 after gpupgrade

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

ALTER TABLE public.pxf_test_hist 
EXCHANGE PARTITION p20260101
WITH TABLE public.ext_r_pxf_test_hist_20260101
WITHOUT VALIDATION;


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





