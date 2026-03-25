--3.3 plr_gp6_test
---------------------------------------------------------------------
--3.3.1 basic

SELECT public.plr_test_return_host();

--------------------------------------------------------------------
--3.3.2
--correlation test & simple r code test

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
--3.3.3
--plr random forest
-- Run UDF, compute predicted value of y for each ID
SELECT sex, (public.plr_test_rf_predict(id, y, x1, x2)).* 
  FROM public.plr_test_abalone_arr;


--------------------------------------------------------------------
--3.3.4
--plr Linear Regression(선형 회귀 분석), Linear Model(선형 모델)  
SELECT sex, (public.plr_test_lm_abalone(s_weight,rings,diameter)).* 
  FROM public.plr_test_lm_abalone_arr;

