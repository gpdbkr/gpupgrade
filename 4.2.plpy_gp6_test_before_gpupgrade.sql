--4.2 plpython3u_gp6_test
---------------------------------------------------------------------
--4.2.1 basic

DROP FUNCTION IF EXISTS public.plpy_max(int, int);
CREATE FUNCTION public.plpy_max(a int, b int)
RETURNS int 
AS 
$$
    if a > b:
        return a
    return b
$$ LANGUAGE 'plpython3u';


SELECT public.plpy_max(1, 2);
/*
plpy_max|
--------+
       2|
 */
--------------------------------------------------------------
--Returning more results: Composite types 
DROP TYPE IF EXISTS public.plpy_named_value CASCADE;
CREATE TYPE public.plpy_named_value AS (
    name text
    , value integer
);

DROP FUNCTION IF EXISTS public.plpy_make_pair(text, integer);
CREATE OR REPLACE FUNCTION public.plpy_make_pair(name text, value integer)
RETURNS public.plpy_named_value
AS $$
    return [name, value]
    # or alternatively, as tuple: return (name, value)
$$ LANGUAGE plpython3u;

SELECT public.plpy_make_pair('LEE', 0);
/*
plpy_make_pair|
--------------+
(LEE,0)       | 
 */
-----------------------------------------------------
--Returniing more results : a sequence type, iterator or generator 
DROP FUNCTION IF EXISTS public.plpy_make_pair2(text);
CREATE FUNCTION public.plpy_make_pair2(name text)
    RETURNS SETOF public.plpy_named_value
AS $$
    return ([name, 0], [name, 1], [name, 2])
$$ LANGUAGE plpython3u;

SELECT public.plpy_make_pair2('LEE');
/*
plpy_make_pair2|
---------------+
(LEE,0)        |
(LEE,1)        |
(LEE,2)        |
 */
-------------------------------------------------

DROP FUNCTION IF EXISTS public.plpy_make_pair3(text);
CREATE FUNCTION public.plpy_make_pair3(name text)
    RETURNS SETOF public.plpy_named_value
AS $$
    for i in range(3):
        yield (name, i)
$$ LANGUAGE plpython3u;

SELECT public.plpy_make_pair3('LEE');

/*
plpy_make_pair3|
---------------+
(LEE,0)        |
(LEE,1)        |
(LEE,2)        |
 */

-------------------------------------------------------
--Array Aggreation and Multi-rows function
DROP TABLE IF EXISTS public.plpy_test_tbl_sample;
CREATE TABLE public.plpy_test_tbl_sample
(
    grp VARCHAR(6) NOT NULL
    , x INTEGER
) 
DISTRIBUTED BY (grp);

INSERT INTO public.plpy_test_tbl_sample 
VALUES
('a', 10)
, ('a', 100)
, ('b', 1000)
, ('b', 10000);

SELECT * FROM public.plpy_test_tbl_sample  ORDER BY grp, x;
/*
grp|x    |
---+-----+
a  |   10|
a  |  100|
b  | 1000|
b  |10000|
*/

-------------------------------------------------------
---- pl/python takes Arrays type for multi-rows from Greenplum as an input
DROP FUNCTION IF EXISTS public.plpy_transform(int[]);
CREATE FUNCTION public.plpy_transform(x int[])
    RETURNS SETOF float8
AS $$
    import numpy as np
    return np.log10(x)
$$ LANGUAGE plpython3u;


SELECT grp, public.plpy_transform(a.x_agg) AS x_log10
FROM (
    SELECT 
        grp, 
        ARRAY_AGG(x) AS x_agg 
    FROM public.plpy_test_tbl_sample 
    GROUP BY grp) a
ORDER BY grp, x_log10;

/*
grp|x_log10|
---+-------+
a  |    1.0|
a  |    2.0|
b  |    3.0|
b  |    4.0|
*/

--------------------------------------------
--2-dimensional array aggregation using MADlib's matrix_add() function
DROP TABLE IF EXISTS public.plpy_test_tbl_multicol;
CREATE TABLE public.plpy_test_tbl_multicol (
    grp VARCHAR(6) NOT NULL
    , id INTEGER
    , x1 INTEGER
    , x2 INTEGER
    , y  INTEGER
) 
DISTRIBUTED BY (grp);

INSERT INTO public.plpy_test_tbl_multicol VALUES 
('a', 1, 10, 20, 100), ('a', 2, 11, 21, 101)
, ('b', 3, 12, 22, 102), ('b', 4, 13, 23, 103);

SELECT * FROM public.plpy_test_tbl_multicol ORDER BY id;
/*
grp|id|x1|x2|y  |
---+--+--+--+---+
a  | 1|10|20|100|
a  | 2|11|21|101|
b  | 3|12|22|102|
b  | 4|13|23|103|
*/

DROP TABLE IF EXISTS public.plpy_test_tbl_2d_agg CASCADE;
CREATE TABLE public.plpy_test_tbl_2d_agg 
AS 
SELECT 
       grp 
     , madlib.matrix_agg(array[x1, x2]) AS feature_2d_arr
     , array_agg(y ORDER BY id) AS y_arr
  FROM public.plpy_test_tbl_multicol
 GROUP BY grp
DISTRIBUTED BY (grp);

SELECT * FROM public.plpy_test_tbl_2d_agg ORDER BY grp;
/*
grp|feature_2d_arr           |y_arr    |
---+-------------------------+---------+
a  |{{10.0,20.0},{11.0,21.0}}|{100,101}|
b  |{{12.0,22.0},{13.0,23.0}}|{102,103}|
*/

-- Returning serialized objects as byte array
DROP FUNCTION IF EXISTS public.plpy_reg_train(features float[][], targets integer[]);
CREATE OR REPLACE FUNCTION public.plpy_reg_train(features float[][], targets integer[])
RETURNS bytea
AS
$$ 
    from sklearn.linear_model import LinearRegression
    
    import six
    pickle = six.moves.cPickle
    
    lin_reg = LinearRegression()
    lin_reg.fit(features, targets)
    
    return pickle.dumps(lin_reg, protocol=3)
$$ LANGUAGE plpython3u;

DROP TABLE IF EXISTS public.plpy_test_reg_model CASCADE;
CREATE TABLE public.plpy_test_reg_model 
AS 
SELECT 
       grp
     , public.plpy_reg_train(feature_2d_arr, y_arr) AS model
  FROM public.plpy_test_tbl_2d_agg
DISTRIBUTED BY (grp)
;

--executiing and preparing SQL Queries
DROP FUNCTION IF EXISTS public.plpy_exe_func();
CREATE OR REPLACE FUNCTION public.plpy_exe_func() 
    RETURNS SETOF text
AS $$
    result = plpy.execute("SELECT * FROM public.plpy_test_tbl_sample WHERE x > 10", 2);
    return result
$$ LANGUAGE plpython3u;

SELECT public.plpy_exe_func();
/*
plpy_exe_func          |
-----------------------+
{'grp': 'a', 'x': 100} |
{'grp': 'b', 'x': 1000}|
 */

CREATE OR REPLACE FUNCTION public.plpy_mean(data float[])
RETURNS float AS
$$
    import pandas as pd
    # 파이썬 리스트를 판다스 시리즈로 변환
    s = pd.Series(data)
    # 평균 계산
    return float(s.mean())
$$ LANGUAGE plpython3u;


SELECT sex, avg(y) y 
  FROM ( 
          SELECT sex, UNNEST(y)  y
          FROM   public.plr_test_abalone_arr
       ) a 
GROUP BY sex 
ORDER BY 1;
/*
sex|id                 |
---+-------------------+
F  |0.44618783473603674|
I  |0.19103502235469447|
M  | 0.4329460078534033|
 */

SELECT sex, public.plpy_mean(y), public.r_avg(y)
FROM public.plr_test_abalone_arr
ORDER BY 1
;
/*
sex|plpy_mean          |r_avg            |
---+-------------------+-----------------+
F  |0.44618783473603674|0.446187834736037|
I  |0.19103502235469447|0.191035022354694|
M  |0.43294600785340315|0.432946007853403|
 */


--4.2.2 utility
CREATE OR REPLACE FUNCTION public.plpy_return_hostname()
  RETURNS varchar AS
$BODY$
             
import subprocess
x = subprocess.check_output("hostname", shell=True, text=True)
return x

$BODY$
LANGUAGE 'plpython3u';

SELECT public.plpy_return_hostname();
/*
plpy_hostname|
-------------+
r9g6s2¶      |
*/

CREATE OR REPLACE FUNCTION public.plpy_lengthb(string text)
RETURNS integer
as
$$
try:
    content = string.encode('cp949')
    rval = len(content)
    return rval
except UnicodeError:
    rval = len(string)
    return rval
$$
LANGUAGE 'plpython3u' IMMUTABLE SECURITY DEFINER;


SELECT length('가나다'), OCTET_LENGTH('가나다'), plpy_lengthb('가나다');
/*
length|octet_length|plpy_lengthb|
------+------------+------------+
     3|           9|           6|
*/
SELECT length('123'), OCTET_LENGTH('123'), plpy_lengthb('123');
/*
length|octet_length|plpy_lengthb|
------+------------+------------+
     3|           3|           3|
*/

-- table copy 
DROP FUNCTION public.plpy_gp_tb_copy_from_src_to_target(v_src_tb varchar, v_target_tb varchar);
CREATE OR REPLACE FUNCTION public.plpy_gp_tb_copy_from_src_to_target(v_src_tb varchar, v_target_tb varchar)
  RETURNS varchar AS
$BODY$
             
    import subprocess
    x = subprocess.check_output('source /usr/local/greenplum-db/greenplum_path.sh; psql -h 172.16.65.22 -p 5432 -U udba -d gpkrtpch -c "copy ' + v_src_tb + ' to STDOUT csv" | psql -h 172.16.65.22 -p 5432 -U udba -d gpkrtpch -c "copy ' + v_target_tb + ' from STDIN csv"', shell=True, text=True)
    return x
$BODY$
LANGUAGE 'plpython3u' IMMUTABLE STRICT;


DROP TABLE IF EXISTS public.plpy_test_copy_src;
CREATE TABLE public.plpy_test_copy_src
(
   param varchar(100),
   lot_id varchar(100),
   val   numeric
)
WITH (APPENDONLY=true, compresslevel=5)
DISTRIBUTED BY (param);

DROP TABLE IF EXISTS public.plpy_test_copy_target;
CREATE TABLE public.plpy_test_copy_target (like public.plpy_test_copy_src)
WITH (APPENDONLY=true, compresslevel=5)
DISTRIBUTED BY (param);

INSERT INTO public.plpy_test_copy_src
SELECT 'param_'||trim(to_char(a, '000000')) param
     , 'lot_'||trim(to_char(b, '0')) lot
     , round((random() * 10)::numeric, 5) val
  FROM generate_series(1, 100) a
     , generate_series(1, 5) b
;

TRUNCATE TABLE public.plpy_test_copy_target;

SELECT count(*) FROM public.plpy_test_copy_src;  --500
SELECT count(*) FROM public.plpy_test_copy_target; --0
SELECT public.plpy_gp_tb_copy_from_src_to_target('public.plpy_test_copy_src', 'public.plpy_test_copy_target');
/*
plpy_gp_tb_copy_from_src_to_target|
----------------------------------+
COPY 500¶                         |
 */
SELECT count(*) FROM public.plpy_test_copy_target; --500


--4.2.3 Classification by logistic regression using plpython
DROP TABLE IF EXISTS public.plpy_test_abalone;
CREATE TABLE public.plpy_test_abalone 
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT * 
  FROM public.plr_test_abalone
DISTRIBUTED BY (id);


DROP TABLE IF EXISTS public.plpy_test_abalone_target;
CREATE TABLE public.plpy_test_abalone_target 
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT 
        id 
        , LOWER(sex) AS sex
        , diameter 
        , shucked_weight 
        , rings
        , CASE WHEN (rings + 1.5) >= 10 THEN 1 ELSE 0 END AS mature
 FROM public.plpy_test_abalone
DISTRIBUTED BY (id);

--Split training and test set
-- Train, Test set split using MADlib
DROP TABLE IF EXISTS public.plpy_test_abalone_split;
DROP TABLE IF EXISTS public.plpy_test_abalone_split_train;
DROP TABLE IF EXISTS public.plpy_test_abalone_split_test;
SELECT madlib.train_test_split(
    'public.plpy_test_abalone_target'      -- source table
    , 'public.plpy_test_abalone_split'     -- output table
    , 0.8                 -- proportion of training set
    , 0.2                 -- proportion of test set
    , 'sex, mature'       -- strata definition
    , 'id, diameter, shucked_weight' -- columns to output
    , FALSE               -- sampling without replacement
    , TRUE                -- separate output tables
);

--SELECT * FROM public.plpy_test_abalone_split_train ORDER BY id LIMIT 5;
--SELECT * FROM public.plpy_test_abalone_split_test ORDER BY id LIMIT 5;

SELECT a.* 
FROM (
      SELECT 'train' AS splitset, sex, mature, COUNT(*) AS cnt 
        FROM public.plpy_test_abalone_split_train
       GROUP BY 1, 2, 3
UNION
      SELECT 'test' AS splitset, sex, mature, COUNT(*) AS cnt 
        FROM public.plpy_test_abalone_split_test 
       GROUP BY 1, 2, 3
) a 
ORDER BY sex, mature, splitset;

DROP TABLE IF EXISTS public.plpy_test_abalone_split_train_agg;
CREATE TABLE public.plpy_test_abalone_split_train_agg AS (
    SELECT 
        sex 
        , ARRAY_AGG(mature) AS mature_agg                 -- y
        , ARRAY_AGG(diameter) AS diameter_agg             -- x1
        , ARRAY_AGG(shucked_weight) AS shucked_weight_agg -- x2
    FROM public.plpy_test_abalone_split_train
    GROUP BY sex
) 
DISTRIBUTED BY (sex);

SELECT * FROM public.plpy_test_abalone_split_train_agg ORDER BY sex;


--Modeling, Logistic regression by sex groups using tython3 for classifcation
DROP TYPE IF EXISTS public.plpy_logit_type CASCADE;
CREATE TYPE public.plpy_logit_type AS (
    col_nm text[]
    , coef float8[]
    , intercept float8
    , serialized_logit_model bytea
);

-- PL/python
-- Define user defined PL/Python function
DROP FUNCTION IF EXISTS public.plpy_logit_func(integer[], float8[], float8[]);
CREATE OR REPLACE FUNCTION public.plpy_logit_func(
    mature integer[]
    , diameter float8[]
    , shucked_weight float8[]
) RETURNS public.plpy_logit_type 
AS $$

    import numpy as np
    import pandas as pd
    from sklearn.linear_model import LogisticRegression
    
    col_nm = ['diameter', 'shucked_weight']
    
    X_train = np.array([diameter, shucked_weight]).T
    y_train = np.array([mature]).T
    
    lr_model = LogisticRegression(penalty='l2', 
                              fit_intercept=True, 
                              solver='lbfgs', 
                              random_state=1004)

    lr_fit = lr_model.fit(X_train, y_train)
    
    # Coefficient of the features
    lr_coef = lr_fit.coef_
    
    # Intecept (a.k.a. bias)
    lr_intercept = lr_fit.intercept_
    
    # Serialization of the fitted model
    import six
    pickle = six.moves.cPickle
    
    lr_serialized_model = pickle.dumps(lr_fit, protocol=3)
    
    # please use Dict for plcontainer composit return type as below
    return {'col_nm': col_nm, 
            'coef': lr_coef[0], 
            'intercept': lr_intercept[0], 
            'serialized_logit_model': lr_serialized_model}
    
$$ LANGUAGE 'plpython3u';


DROP TABLE IF EXISTS public.plpy_test_abalone_logit_fitted;
CREATE TABLE public.plpy_test_abalone_logit_fitted 
AS 
 SELECT 
        sex, 
        (public.plpy_logit_func(
            mature_agg, 
            diameter_agg, 
            shucked_weight_agg)).*
    FROM public.plpy_test_abalone_split_train_agg
DISTRIBUTED BY (sex);

-- PL/python: Define the UDF for Prediction (Classification)
DROP FUNCTION IF EXISTS public.plpy_logit_pred_func(bytea, float8[]);
CREATE OR REPLACE FUNCTION public.plpy_logit_pred_func(serialized_model bytea, features float8[]) 
RETURNS float8
AS $$

    # Deserialize the model
    import six
    pickle = six.moves.cPickle
    model = pickle.loads(serialized_model)
    
    # Predict the probability of classes (0, 1)
    # We will only return the probability of '1(True) class' of 1st row
    pred_proba = model.predict_proba([features])
    
    return pred_proba[0, 1]
    
$$ LANGUAGE 'plpython3u';

DROP TABLE IF EXISTS public.plpy_test_abalone_logit_predicted;
CREATE TABLE public.plpy_test_abalone_logit_predicted 
AS 
SELECT 
       test.id
     , test.sex
     , test.mature
     , public.plpy_logit_pred_func(
            model.serialized_logit_model      -- bytea
            , ARRAY[diameter, shucked_weight] -- float8 array
     ) AS pred_proba
    FROM public.plpy_test_abalone_split_test  AS test
       , public.plpy_test_abalone_logit_fitted AS model
    WHERE test.sex = model.sex
DISTRIBUTED BY (sex);

SELECT 
       test.id
     , test.sex
     , test.mature
     , public.plpy_logit_pred_func(
            model.serialized_logit_model      -- bytea
            , ARRAY[diameter, shucked_weight] -- float8 array
     ) AS pred_proba
 FROM public.plpy_test_abalone_split_test  AS test
    , public.plpy_test_abalone_logit_fitted AS model
WHERE test.sex = model.sex
;

--4.2.4 pl/python3 - Linear regression 
--Split training and test set
-- Train, Test set split using MADlib

DROP TABLE IF EXISTS public.plpy_test_abalone2;
CREATE TABLE public.plpy_test_abalone2 
WITH (appendonly=TRUE, compresstype=zstd, compresslevel=7)
AS 
SELECT * 
  FROM public.plr_test_abalone
DISTRIBUTED BY (id);


DROP TABLE IF EXISTS public.plpy_test_abalone2_split;
SELECT madlib.train_test_split(
    'public.plpy_test_abalone2'             -- source table
    , 'public.plpy_test_abalone2_split'     -- output table
    , 0.8                 -- proportion of training set
    , 0.2                 -- proportion of test set
    , 'sex'               -- strata definition
    , NULL                -- columns to output
    , FALSE               -- sampling with replacement
    , FALSE);             -- separate output tables
    
--SELECT * FROM public.plpy_test_abalone2;
--SELECT * FROM public.plpy_test_abalone2_split;

--define the return composite type
DROP TYPE IF EXISTS public.plpy_linreg_type CASCADE;
CREATE TYPE public.plpy_linreg_type AS (
    col_nm text[]
    , coef float8[]
    , intercept float8
    , serialized_linreg_model bytea
    , created_dt text
);

DROP FUNCTION IF EXISTS public.plpy_linreg_func(float8[], float8[], int[]);
CREATE OR REPLACE FUNCTION public.plpy_linreg_func(
    length float8[]
    , shucked_weight float8[]
    , rings float8[]
) RETURNS public.plpy_linreg_type 
AS $$
    from sklearn.linear_model import LinearRegression
    import numpy as np
    
    X = np.array([length, shucked_weight]).T
    y = np.array([rings]).T
    
    # OLS linear regression with length, shucked_weight
    linreg_fit = LinearRegression().fit(X, y)
    linreg_coef = linreg_fit.coef_
    linreg_intercept = linreg_fit.intercept_
    
    # Serialization of the fitted model
    import six; import datetime
    pickle = six.moves.cPickle
    serialized_linreg_model = pickle.dumps(linreg_fit, protocol=3) # protocol = 3 for Python 3.x
    
    return {
        'col_nm': ['length', 'shucked_weight'],
        'coef': linreg_coef[0],
        'intercept': linreg_intercept[0],
        'serialized_linreg_model': serialized_linreg_model,
        'created_dt': str(datetime.datetime.now())}
    
$$ LANGUAGE 'plpython3u';

--Linear Regression - Exexute the OLS Linear Regression Function by sex
DROP TABLE IF EXISTS public.plpy_test_abalone2_linreg_fitted;
CREATE TABLE public.plpy_test_abalone2_linreg_fitted 
AS 
SELECT
       a.sex
     , (public.plpy_linreg_func(
              a.length_agg
            , a.shucked_weight_agg
            , a.rings_agg)
        ).*
  FROM (
        SELECT
            sex
            , ARRAY_AGG(length) AS length_agg
            , ARRAY_AGG(shucked_weight) AS shucked_weight_agg
            , ARRAY_AGG(rings) AS rings_agg
        FROM public.plpy_test_abalone2_split
        WHERE split = 1
        GROUP BY sex
    ) a
DISTRIBUTED BY (sex);


DROP FUNCTION IF EXISTS public.plpy_linreg_pred_func(bytea, float8[]);
CREATE FUNCTION public.plpy_linreg_pred_func(
    serialized_model bytea
    , features float8[]
) RETURNS SETOF float8
AS $$
    # Deserialize the serialized model
    import six
    pickle = six.moves.cPickle
    model = pickle.loads(serialized_model)
    
    # Predict the target variable
    y_pred = model.predict([features])
    
    return y_pred[0]

$$ LANGUAGE 'plpython3u';


DROP TABLE IF EXISTS public.plpy_test_abalone2_linreg_pred;
CREATE TABLE public.plpy_test_abalone2_linreg_pred 
AS 
SELECT 
        test.id
        , test.sex
        , test.rings
        , public.plpy_linreg_pred_func(
            model.serialized_linreg_model   -- bytea
            , ARRAY[length, shucked_weight] -- array
        ) AS y_pred
    FROM 
        (SELECT * FROM public.plpy_test_abalone2_split WHERE split=0) AS test
        , public.plpy_test_abalone2_linreg_fitted AS model
    WHERE test.sex = model.sex
DISTRIBUTED BY (sex);




