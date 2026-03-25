psql -U gpadmin -AtX > 3.1.plr_gp6_install_2_permision_tmp.sh  2>&1 <<EOF
SELECT 'PGOPTIONS=''-c gp_session_role=utility'' psql -h '||hostname||' -p '||port||' -c "
    SET allow_system_table_mods=ON;
    UPDATE pg_language SET lanpltrusted = TRUE WHERE lanname = ''plr'';" '  
FROM gp_segment_configuration WHERE ROLE = 'p';
EOF

/bin/bash 3.1.plr_gp6_install_2_permision_tmp.sh
