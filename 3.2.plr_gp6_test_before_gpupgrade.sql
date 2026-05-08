--3.2 plr_gp6_test
---------------------------------------------------------------------
--3.2.1 basic
CREATE OR REPLACE FUNCTION public.plr_test_return_host()
RETURNS varchar AS
$BODY$
  return(system("hostname",intern=T))
$BODY$
LANGUAGE 'plr';

SELECT public.plr_test_return_host();

--------------------------------------------------------------------
--3.2.2
--correlation test & simple r code test
DROP TABLE IF EXISTS public.plr_test_corr;

CREATE TABLE public.plr_test_corr
(
   param varchar(100),
   lot_id varchar(100),
   val   numeric
)
WITH (APPENDONLY=true, compresslevel=5)
DISTRIBUTED BY (param);

INSERT INTO public.plr_test_corr
SELECT 'param_'||trim(to_char(a, '000000')) param
     , 'lot_'||trim(to_char(b, '0')) lot
     , round((random() * 10)::numeric, 5) val
  FROM generate_series(1, 100) a
     , generate_series(1, 5) b
;

CREATE OR REPLACE FUNCTION public.r_corr(numeric[], numeric[]) 
RETURNS numeric 
AS 
$body$
       return (cor(arg1, arg2))
$body$
LANGUAGE plr IMMUTABLE;

SELECT a.param, b.param, --a.val_array, b.val_array,
       r_corr(a.val_array, b.val_array) corr_val
  FROM (
           SELECT  param, array_agg(val ORDER BY lot_id) val_array
           FROM    public.plr_test_corr a
           GROUP BY param
        ) a,
        (
           SELECT  param, array_agg(val ORDER BY lot_id)  val_array
             FROM  public.plr_test_corr a
            GROUP BY param
       ) b    
 WHERE  a.param <> b.param
 ORDER BY 1, 2 ;


CREATE OR REPLACE FUNCTION public.r_sum(numeric[])
RETURNS numeric AS
$BODY$
     return (sum(arg1))
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_max(anyarray)
RETURNS anyelement AS
$BODY$
     return (max(arg1))
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_min(anyarray)
RETURNS anyelement AS
$BODY$
     return (min(arg1))
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_avg(anyarray)
RETURNS numeric AS
$BODY$
     return (mean(arg1))
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_std(numeric[])
RETURNS numeric AS
$BODY$
     return (sd(arg1))
$BODY$
LANGUAGE plr IMMUTABLE;

CREATE OR REPLACE FUNCTION public.r_median(anyarray)
RETURNS numeric AS
$BODY$
     return (quantile(arg1, 0.5, NaN.rm  = TRUE, na.rm = TRUE))
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_count_rlength(anyarray)
RETURNS bigint AS
$BODY$
cnt <- length(arg1)
return (cnt)
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_count_arr_upper(anyarray)
RETURNS bigint AS $$
BEGIN
      return array_upper($1, 1);
END;
$$ LANGUAGE plpgsql IMMUTABLE ;


CREATE OR REPLACE FUNCTION public.r_arr_uniq(anyarray)
RETURNS anyarray AS
$BODY$
val <- arg1
val_unique <- unique(val)
return (val_unique)
$BODY$
LANGUAGE plr IMMUTABLE;


CREATE OR REPLACE FUNCTION public.r_arr_uniq_count(anyarray)
RETURNS bigint AS
$BODY$
val <- arg1
val_unique <- unique(val)
cnt <- length(val_unique)
return (cnt)
$BODY$
LANGUAGE plr IMMUTABLE;


SELECT r_max(i) max, r_min(i) min, r_avg(i), r_std(i), r_count_rlength(i)
  FROM (
         SELECT array_agg(i%2) i
           FROM generate_series(1, 100) i
       ) aa
;

SELECT r_arr_uniq(i), r_arr_uniq_count(i)
  FROM (
         SELECT array_agg(i%2) i
           FROM generate_series(1, 100) i
       ) aa
;


--------------------------------------------------------------------
--3.2.3
--plr random forest
--data download: wget http://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data

DROP TABLE IF EXISTS public.plr_test_abalone;

CREATE TABLE public.plr_test_abalone 
(
    id serial, 
    sex text, 
    length float8, 
    diameter float8, 
    height float8, 
    whole_weight float8, 
    shucked_weight float8, 
    viscera_weight float8, 
    shell_weight float8, 
    rings float8
)
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
DISTRIBUTED BY(id);

--loading data from file to Greenplum database in psql
COPY public.plr_test_abalone (sex, length, diameter, height, whole_weight, shucked_weight, viscera_weight, shell_weight,rings) FROM '/data/gpupgrade/abalone.data' WITH CSV;
-- Create array version of table, grouped by sex

DROP TABLE IF EXISTS public.plr_test_abalone_arr;
CREATE TABLE public.plr_test_abalone_arr 
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT
       sex::text
     , array_agg(id::int order by id) as id
     , array_agg(shucked_weight::float8 order by id) as y
     , array_agg(rings::float8 order by id) as x1
     , array_agg(diameter::float8 order by id) as x2
  FROM public.plr_test_abalone
 GROUP BY sex
DISTRIBUTED BY (sex);

--Create type to store prediction results from random forest models
DROP TYPE IF EXISTS public.plr_test_rf_predict_type CASCADE;
CREATE TYPE public.plr_test_rf_predict_type 
AS 
(
    id int, 
    s_weight_predicted float8
);

-- Create UDF to run a random forest model for each group. In other words, run a random forest model for each group and return predicted values
CREATE OR REPLACE FUNCTION public.plr_test_rf_predict(id int[], y float8[], x1 float8[], x2 float8[])
RETURNS SETOF public.plr_test_rf_predict_type AS
$$
library(randomForest)
m1<- randomForest(y ~ x1 + x2)
temp_m1<- data.frame(id, predict(m1))
return(temp_m1)
$$
LANGUAGE 'plr';


-- Run UDF, compute predicted value of y for each ID
SELECT sex, (public.plr_test_rf_predict(id, y, x1, x2)).* 
  FROM public.plr_test_abalone_arr;

-- Do same as above, but save results to table
DROP TABLE IF EXISTS public.plr_test_rf_abalone_predict ;
CREATE TABLE public.plr_test_rf_abalone_predict 
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT sex, (public.plr_test_rf_predict(id, y, x1, x2)).* 
  FROM public.plr_test_abalone_arr
DISTRIBUTED BY (id);

SELECT * 
  FROM public.plr_test_rf_abalone_predict  
 ORDER BY id;


--------------------------------------------------------------------
--3.2.4
--plr Linear Regression(선형 회귀 분석), Linear Model(선형 모델)  
DROP TABLE IF EXISTS public.plr_test_lm_abalone_arr;
CREATE TABLE public.plr_test_lm_abalone_arr
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT 
       sex::text
     , array_agg(shucked_weight::float8) as s_weight
     , array_agg(rings::float8) as rings
     , array_agg(diameter::float8) as diameter 
  FROM public.plr_test_abalone 
 GROUP BY sex 
DISTRIBUTED BY (sex);

DROP TYPE IF EXISTS public.plr_test_lm_abalone_type CASCADE;
CREATE TYPE public.plr_test_lm_abalone_type 
AS 
(
    Variable text, Coef_Est float, Std_Error float, T_Stat float, P_Value float
); 

CREATE OR REPLACE FUNCTION public.plr_test_lm_abalone
(s_weight float8[], rings float8[], diameter float8[]) 
RETURNS SETOF public.plr_test_lm_abalone_type  AS 
$$ 
    m1<- lm(s_weight~rings+diameter)
    m1_s<- summary(m1)$coef
    temp_m1<- data.frame(rownames(m1_s), m1_s)
    return(temp_m1)
$$ 
LANGUAGE 'plr';


SELECT sex, (public.plr_test_lm_abalone(s_weight,rings,diameter)).* 
  FROM public.plr_test_lm_abalone_arr;

