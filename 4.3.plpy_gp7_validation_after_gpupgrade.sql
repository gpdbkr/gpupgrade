--4.3 plpython3u_gp7_test
---------------------------------------------------------------------
--4.3.1 basic
SELECT public.plpy_max(1, 2);
SELECT public.plpy_make_pair('LEE', 0);
SELECT public.plpy_make_pair2('LEE');
SELECT public.plpy_make_pair3('LEE');

SELECT grp, public.plpy_transform(a.x_agg) AS x_log10
FROM (
    SELECT 
        grp, 
        ARRAY_AGG(x) AS x_agg 
    FROM public.plpy_test_tbl_sample 
    GROUP BY grp) a
ORDER BY grp, x_log10;

SELECT 
       grp
     , public.plpy_reg_train(feature_2d_arr, y_arr) AS model
  FROM public.plpy_test_tbl_2d_agg
;  

SELECT public.plpy_exe_func();

SELECT sex, public.plpy_mean(y), public.r_avg(y)
FROM public.plr_test_abalone_arr
ORDER BY 1
;

--4.3.2 utility
SELECT public.plpy_return_hostname();
SELECT length('123'), OCTET_LENGTH('123'), plpy_lengthb('123');
SELECT length('가나다'), OCTET_LENGTH('가나다'), plpy_lengthb('가나다');

TRUNCATE TABLE public.plpy_test_copy_target;
SELECT count(*) FROM public.plpy_test_copy_src;  --500
SELECT count(*) FROM public.plpy_test_copy_target; --0
SELECT public.plpy_gp_tb_copy_from_src_to_target('public.plpy_test_copy_src', 'public.plpy_test_copy_target');
SELECT count(*) FROM public.plpy_test_copy_target; --500

--4.3.3 Classification by logistic regression using plpython
--Execute the PL/python Logistic Regression UDF
 SELECT 
        sex, 
        (public.plpy_logit_func(
            mature_agg, 
            diameter_agg, 
            shucked_weight_agg)).*
    FROM public.plpy_test_abalone_split_train_agg
;

-- Execute the Prediction function
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


--4.3.4 pl/python3 - Linear regression 
--Split training and test set
-- Train, Test set split using MADlib

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
;

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
 ;



