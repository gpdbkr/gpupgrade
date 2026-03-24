--2.2. MADlib Test for Greenplum 6
--2.2.1 one_way_anova

drop table if exists public.madlib_test_header_anova ;
create table public.madlib_test_header_anova
(
    sn varchar(100),
    gtc_tp varchar(100),
    dttm timestamp,
    prjname varchar(100),
    line varchar(100),
    corp_name varchar(100),
    exam_no int,
    val numeric(10,2),
    max_val numeric(10,2),
    min_val numeric(10,2)
)
WITH (appendonly=true, compresslevel=7, orientation=row, compresstype=zstd)
DISTRIBUTED BY (sn)
;

insert into public.madlib_test_header_anova
select 'SN'||trim(to_char(b.idx, '0000000000')) sn
     , 'GTCTP_'||trim(to_char(b.idx, '000')) gtc_tp
     , now() + (''||b.idx||' day')::interval
     , 'PRJ_'||trim(to_char(b.idx, '000')) prjname
     , 'LINE_'||trim(to_char(b.idx, '000')) line
     , 'CORPNAME_'||trim(to_char(b.idx, '000')) corp_name
     , i exam_no
     , case when idx > 11 and idx < 15 then random()*100 * 1.5 else (i % 10 + 1) * random() * 1.5 end val
     , case when idx > 11 and idx < 15 then random()*100 * 1.7 else (i % 10 + 1) * random() * 1.7 end max_val
     , case when idx > 11 and idx < 15 then random()*100 * 1.2 else (i % 10 + 1) * random() * 1.2 END min_val
 from (select i from generate_series (1, 1000) i ) a
    , (select idx from generate_series (1, 100) idx ) b 
;
    
select (MADlib.one_way_anova (exam_no, val)).*
  from (
         select exam_no, val
         from public.madlib_test_header_anova
) a ;

/*
sum_squares_between|sum_squares_within|df_between|df_within|mean_squares_between|mean_squares_within|statistic         |p_value|
-------------------+------------------+----------+---------+--------------------+-------------------+------------------+-------+
   502036.505640479|   20814370.074329|       999|    99000|   502.5390446851642|  210.2461623669596|2.3902412249886504|      0|
*/   

--2.2.2 K-means
DROP TABLE IF EXISTS public.madlib_test_header_cluster;
   
CREATE TABLE public.madlib_test_header_cluster
(
    sn varchar(100),
    gtc_tp varchar(100),
    dttm timestamp,
    prjname varchar(100),
    line varchar(100),
    corp_name varchar(100),
    exam_no int,
    val numeric(10,2),
    max_val numeric(10,2),
    min_val numeric(10,2)
) 
WITH (appendonly=true, compresslevel=7, orientation=row, compresstype=zstd)
DISTRIBUTED BY (SN) ;

INSERT INTO public.madlib_test_header_cluster
SELECT 'SN'||trim(to_char(b.idx, '0000000000')) sn
     , 'GTCTP_'||trim(to_char(b.idx, '000')) gtc_tp
     , now() + (''||b.idx||' day')::interval
     , 'PRJ_'||trim(to_char(b.idx, '000')) prjname
     , 'LINE_'||trim(to_char(b.idx, '000')) line
     , 'CORPNAME_'||trim(to_char(b.idx, '000')) corp_name
     , i exam_no
     , (i % 4) + case when i % 11 = 0 then random() * 1.5 else random()/2 end val
     , (i % 2) + case when i % 27 = 0 then random() * 1.2 else random()/1.5 end max_val
     , (i % 4) + random() min_var
 FROM (SELECT i FROM generate_series (1, 1000) i ) a
    , (SELECT idx FROM generate_series (1, 1) idx) b;
    
CREATE TABLE public.madlib_test_header_cluster_array
WITH (appendonly=true, compresslevel=7, orientation=row, compresstype=zstd)
AS
SELECT exam_no, array[val, max_val] val--, max_val, min_val] val
  FROM public.madlib_test_header_cluster
DISTRIBUTED BY (exam_no);

SELECT data.*, (madlib.closest_column(centroids, val)).column_id as cluster_id
FROM public.madlib_test_header_cluster_array as data,
     (SELECT centroids
        FROM madlib.kmeanspp('public.madlib_test_header_cluster_array', 'val', 4
                             , 'madlib.squared_dist_norm2', 'madlib.avg', 20, 0.001)
     ) as centroids
ORDER BY data.exam_no ;
/* 
exam_no|val        |cluster_id|
-------+-----------+----------+
      1|{1.26,1.31}|         0|
      2|{2.25,0.49}|         1|
      3|{3.22,1.18}|         3|
      4|{0.35,0.61}|         2|
      5|{1.28,1.08}|         0|
      6|{2.22,0.21}|         1|
      7|{3.33,1.32}|         3|
      8|{0.24,0.47}|         2|
...
*/


--2.2.3 Random Forest 
--Split up the original example table into two tables (see https://madlib.apache.org/docs/latest/group__grp__random__forest.html for reference)

DROP TABLE IF EXISTS public.madlib_test_rf_golf CASCADE;
CREATE TABLE public.madlib_test_rf_golf (
    id integer NOT NULL,
    outlook text,
    temperature double precision,
    humidity double precision,
    "Temp_Humidity" double precision[],
    clouds_airquality text[],
    windy boolean,
    class text
)
WITH (appendonly=true, compresslevel=7, orientation=row, compresstype=zstd)
DISTRIBUTED BY (id)
;

INSERT INTO public.madlib_test_rf_golf VALUES
(1,'sunny', 85, 85, ARRAY[85, 85],ARRAY['none', 'unhealthy'], 'false','Don''t Play'),
(2, 'sunny', 80, 90, ARRAY[80, 90], ARRAY['none', 'moderate'], 'true', 'Don''t Play'),
(3, 'overcast', 83, 78, ARRAY[83, 78], ARRAY['low', 'moderate'], 'false', 'Play'),
(4, 'rain', 70, 96, ARRAY[70, 96], ARRAY['low', 'moderate'], 'false', 'Play'),
(5, 'rain', 68, 80, ARRAY[68, 80], ARRAY['medium', 'good'], 'false', 'Play'),
(6, 'rain', 65, 70, ARRAY[65, 70], ARRAY['low', 'unhealthy'], 'true', 'Don''t Play'),
(7, 'overcast', 64, 65, ARRAY[64, 65], ARRAY['medium', 'moderate'], 'true', 'Play'),
(8, 'sunny', 72, 95, ARRAY[72, 95], ARRAY['high', 'unhealthy'], 'false', 'Don''t Play'),
(9, 'sunny', 69, 70, ARRAY[69, 70], ARRAY['high', 'good'], 'false', 'Play'),
(10, 'rain', 75, 80, ARRAY[75, 80], ARRAY['medium', 'good'], 'false', 'Play'),
(11, 'sunny', 75, 70, ARRAY[75, 70], ARRAY['none', 'good'], 'true', 'Play'),
(12, 'overcast', 72, 90, ARRAY[72, 90], ARRAY['medium', 'moderate'], 'true', 'Play'),
(13, 'overcast', 81, 75, ARRAY[81, 75], ARRAY['medium', 'moderate'], 'false', 'Play'),
(14, 'rain', 71, 80, ARRAY[71, 80], ARRAY['low', 'unhealthy'], 'true', 'Don''t Play');

DROP TABLE IF EXISTS public.madlib_test_rf_golf_part1;
CREATE TABLE public.madlib_test_rf_golf_part1 
as 
SELECT id as id, class, outlook , temperature 
  FROM  public.madlib_test_rf_golf
DISTRIBUTED BY (id);

DROP TABLE IF EXISTS public.madlib_test_rf_golf_part2;
CREATE TABLE public.madlib_test_rf_golf_part2 
as 
SELECT id as id, class, humidity, windy 
  FROM  public.madlib_test_rf_golf
DISTRIBUTED BY (id);

--Combine the variables from the two tables into a single table with one column containing all categorical variables and another column containing all quantitative variables
DROP TABLE IF EXISTS public.madlib_test_rf_golf_combined_array;
CREATE TABLE public.madlib_test_rf_golf_combined_array 
AS  
SELECT 
       a.id
     , a.class
     , array[outlook, windy]::text[] as x_categorical 
     , array[temperature, humidity]::double precision[] as x_numeric 
 FROM public.madlib_test_rf_golf_part1 a 
 JOIN public.madlib_test_rf_golf_part2 b 
   ON a.id = b.id  
;

SELECT * FROM public.madlib_test_rf_golf_combined_array LIMIT 1;

/*
id|class|x_categorical  |x_numeric  |
--+-----+---------------+-----------+
12|Play |{overcast,true}|{72.0,90.0}|
*/

--Train RF model
DROP TABLE IF EXISTS public.madlib_test_rf_golf_combined_array_output cascade;
DROP TABLE IF EXISTS public.madlib_test_rf_golf_combined_array_output_group ;
DROP TABLE IF EXISTS public.madlib_test_rf_golf_combined_array_output_summary ;

SELECT madlib.forest_train('public.madlib_test_rf_golf_combined_array',         -- source table
                           'public.madlib_test_rf_golf_combined_array_output',    -- output model table
                           'id',              -- id column
                           'class',           -- response
                           'x_categorical, x_numeric',   -- features
                           NULL,              -- exclude columns
                           NULL,              -- grouping columns
                           20::integer,       -- number of trees
                           2::integer,        -- number of random features
                           TRUE::boolean,     -- variable importance
                           1::integer,        -- num_permutations
                           8::integer,        -- max depth
                           3::integer,        -- min split
                           1::integer,        -- min bucket
                           10::integer        -- number of splits per continuous variable
                           );

--Review Model
                        
SELECT * FROM public.madlib_test_rf_golf_combined_array_output_summary;

/*
method      |is_classification|source_table                             |model_table                                     |id_col_name|dependent_varname|independent_varnames                                               |cat_features                         |con_features                 |grouping_cols|num_trees|num_random_features|max_tree_depth|min_split|min_bucket|num_splits|verbose|importance|num_permutations|num_all_groups|num_failed_groups|total_rows_processed|total_rows_skipped|dependent_var_levels|dependent_var_type|independent_var_types                         |null_proxy|
------------+-----------------+-----------------------------------------+------------------------------------------------+-----------+-----------------+-------------------------------------------------------------------+-------------------------------------+-----------------------------+-------------+---------+-------------------+--------------+---------+----------+----------+-------+----------+----------------+--------------+-----------------+--------------------+------------------+--------------------+------------------+----------------------------------------------+----------+
forest_train|true             |public.madlib_test_rf_golf_combined_array|public.madlib_test_rf_golf_combined_array_output|id         |class            |(x_categorical)[1],(x_categorical)[2],(x_numeric)[1],(x_numeric)[2]|(x_categorical)[1],(x_categorical)[2]|(x_numeric)[1],(x_numeric)[2]|             |       20|                  2|             8|        3|         1|        10|false  |true      |               1|             1|                0|                  14|                 0|Don't Play,Play     |text              |text, text, double precision, double precision|None      |
*/

DROP TABLE IF EXISTS public.madlib_test_rf_golf_combined_array_output_import;
SELECT madlib.get_var_importance('public.madlib_test_rf_golf_combined_array_output','public.madlib_test_rf_golf_combined_array_output_import');
SELECT * 
  FROM public.madlib_test_rf_golf_combined_array_output_import 
 ORDER BY oob_var_importance DESC;

/*
feature           |oob_var_importance|impurity_var_importance|
------------------+------------------+-----------------------+
(x_categorical)[2]| 54.32595573440644|     12.552764672904853|
(x_categorical)[1]|26.358148893360152|     34.386475924377976|
(x_numeric)[2]    |19.315895372233406|      31.20882269985127|
(x_numeric)[1]    |               0.0|     21.851936702865903|
*/

--Generate Predictions

DROP TABLE IF EXISTS public.madlib_test_rf_golf_prediction_results_array;
SELECT madlib.forest_predict('public.madlib_test_rf_golf_combined_array_output',        -- tree model
                             'public.madlib_test_rf_golf_combined_array',             -- new data table
                             'public.madlib_test_rf_golf_prediction_results_array',  -- output table
                             'prob');               -- show probability

SELECT g.id, class, "estimated_prob_Don't Play",  "estimated_prob_Play"
  FROM public.madlib_test_rf_golf_prediction_results_array p
     , public.madlib_test_rf_golf_combined_array g 
 WHERE p.id = g.id 
 ORDER BY g.id;

/*
id|class     |estimated_prob_Don't Play|estimated_prob_Play|
--+----------+-------------------------+-------------------+
 1|Don't Play|                      0.8|                0.2|
 2|Don't Play|                      0.9|                0.1|
 3|Play      |                     0.05|               0.95|
 4|Play      |                     0.45|               0.55|
 5|Play      |                      0.2|                0.8|
 6|Don't Play|                     0.65|               0.35|
 7|Play      |                     0.15|               0.85|
 8|Don't Play|                      0.8|                0.2|
 9|Play      |                     0.15|               0.85|
10|Play      |                     0.25|               0.75|
11|Play      |                      0.3|                0.7|
12|Play      |                      0.4|                0.6|
13|Play      |                      0.0|                1.0|
14|Don't Play|                      0.7|                0.3|
 */



