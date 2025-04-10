--@@  Incidents  @@--
select *
  from gv$(cursor(
  select 
     to_number(substr(dbms_session.unique_session_id,9,4),'XXXX') inst_id
    ,t.* 
from v$diag_incident t
))
where inst_id = &inst_id
order by 4 desc;


--@@  ACTIVE_SESSION_HISTORY  @@--
select count(*),
       min(sample_time),
       max(sample_time),
       count(distinct sql_exec_id),
       inst_id,
       session_id,
       session_serial#,
       sql_opname,
       sql_id,
       sql_plan_hash_value
  from gv$active_session_history s
 where 1=1
 and sql_id = '&sql_id'
-- and inst_id = ?
-- and session_id = ?
-- and session_serial# = ?
 group by inst_id,
          session_id,
          session_serial#,
          sql_opname,
          sql_id,
          sql_plan_hash_value
 order by 2 desc;

--@@  mysid  @@--
select
        to_number(substr(dbms_session.unique_session_id,1,4),'XXXX') sid,
        to_number(substr(dbms_session.unique_session_id,5,4),'XXXX') serial#,
        to_number(substr(dbms_session.unique_session_id,9,4),'XXXX') instance
from
        dual
;


--@@  pack_sql_profile  @@--
begin
  dbms_sqltune.pack_stgtab_sqlprof(profile_name => '&profile_name',staging_table_name => 'PROFILE_STGTAB');
end;

--@@  change password  @@--
alter user egcme4t profile default;
alter user egcme4t identified by MD0racle8$;
alter user egcme4t profile vip_profile;

--@@  lock_info  @@--
select /*+ RULE */
k.inst_id,
ss.username,
decode(request, 0, 'Holder: ', ' Waiter: ') || k.sid sess,
ss.sql_id,
k.id1,
k.id2,
k.lmode,
k.request,
k.type,
ss.last_call_et,
ss.seconds_in_wait,
ss.serial#,
ss.machine,
ss.event,
ss.status,
p.spid,
case
   when request > 0 then
    chr(bitand(p1, -16777216) / 16777215) ||
    chr(bitand(p1, 16711680) / 65535)
   else
    null
end "Name",
case
   when request > 0 then
    (bitand(p1, 65535))
   else
    null
end "Mode"
  from gv$lock k, gv$session ss, gv$process p
where (k.id1, k.id2, k.type) in
       (select ll.id1, ll.id2, ll.type from gv$lock ll where request > 0)
   and k.sid = ss.sid
   and k.inst_id = ss.inst_id
   and ss.paddr = p.addr
   and ss.inst_id = p.inst_id
order by id1, request;

--@@  tables_referenced_by_view  @@--
select distinct OWNER,
                name,
                type,
                referenced_owner,
                referenced_name,
                referenced_type
  from dba_dependencies t
 where referenced_type in ('TABLE', 'VIEW')
   and type in ('TABLE', 'VIEW')
   and referenced_owner not in ('SYS')
 start with owner = '&OWNER'
        and name = '&NAME'
connect by nocycle OWNER = prior referenced_owner
       and name = prior referenced_name
       and prior type in ('TABLE', 'VIEW');

--@@  modify_rsrc_undo_pool  @@--
begin
  dbms_resource_manager.clear_pending_area();
  dbms_resource_manager.create_pending_area();
  dbms_resource_manager.update_plan_directive(plan             => '&plan',
                                              group_or_subplan => '&group',
                                              new_undo_pool    => &new_undo_pool);
  dbms_resource_manager.submit_pending_area();
end;


--@@  incidents (on given instance)  @@--
select *
  from gv$(cursor(
  select 
     to_number(substr(dbms_session.unique_session_id,9,4),'XXXX') inst_id
    ,t.* 
from v$diag_incident t
))
-- where inst_id = &inst_id
order by 3 desc;


--@@  sessions_info_lock_trx_temp  @@--
select
   o.owner locked_object_owner,
   o.object_name locked_object_name,
   o.object_type locked_object_type,
   s.username,
   s.sid,
   s.serial#,
   s.sql_id,
   s.status,
   s.osuser,
   s.machine,
   t.used_urec,
   t.used_ublk,
   decode(bitand(t.flag, 128),0,'N',null,null,'Y') is_rollback,
   s.resource_consumer_group,
   p.pga_used_mem,
   p.pga_alloc_mem,
   p.pga_max_mem,
   su.blocks * tbs.block_size / 1024 / 1024 temp_mb_used,
   p.spid,
   'alter system kill session '''||s.sid||','||s.serial#||',@'||s.inst_id||''';' kill_db_session,
   'kill -9 '||p.spid kill_unix_session
from
   gv$locked_object la ,
   gv$session s,
   gv$process p,
   gv$transaction t,
   ( select sum(blocks) blocks,tablespace, session_addr, inst_id
     from gv$sort_usage
     group by tablespace, session_addr, inst_id) su,
     dba_objects o,
     dba_tablespaces tbs
where    s.sid = la.session_id
  and    la.object_id = o.object_id
  and    s.inst_id=la.inst_id
  and    s.inst_id=p.inst_id
  and    s.paddr=p.addr
  and    s.inst_id=t.inst_id(+)
  and    s.taddr = t.addr(+)
  and    s.inst_id = su.inst_id(+)
  and    s.saddr = su.session_addr
  and    su.tablespace = tbs.tablespace_name(+)
  and    s.username <> 'SYS'
  and    s.type = 'USER';


--@@  Explain plan objects statistics  @@--
--  explain plan for 
--  select * from ...
with t as
 (select distinct object_owner owner,
                  object_name,
                  regexp_substr(object_type, '\w+')
    from plan_table
   where object_owner is not null
     and object_type is not null
     and object_type <> 'VIEW'
     and object_owner <> 'SYS'),
t1 as
 (SELECT nvl(i.table_owner, t.owner) as owner,
         nvl(i.table_name, t.object_name) as table_name
    FROM t, dba_indexes i
   where t.owner = i.owner(+)
     and t.object_name = i.index_name(+))
select case
         when partition_name is not null and subpartition_name is null THEN
          'dbms_stats.gather_table_stats(ownname=>''' || s.owner ||
          ''', tabname =>''' || s.table_name ||
          ''', degree=>32, granularity => ''PARTITION'', partname => ''' ||
          partition_name || ''');'
         when partition_name is not null and subpartition_name is not null THEN
          'dbms_stats.gather_table_stats(ownname=>''' || s.owner ||
          ''', tabname =>''' || s.table_name ||
          ''', degree=>32, granularity => ''SUBPARTITION'', partname => ''' ||
          subpartition_name || ''');'
         when partition_name is  null and subpartition_name is  null THEN
          'dbms_stats.gather_table_stats(ownname=>''' || s.owner ||
          ''', tabname =>''' || s.table_name ||
          ''', degree=>32);'
       end gather_stats,
       s.*
  from dba_tab_statistics s, t1
 where s.owner = t1.owner
   and s.table_name = t1.table_name
   and (stale_stats = 'YES' or stale_stats is null);


--@@  ASH  @@--
select count(*),
       min(sample_time),
       max(sample_time),
       count(distinct sql_exec_id),
       instance_number,
       session_id,
       session_serial#,
       sql_opname,
       sql_id,
       sql_plan_hash_value
  from dba_hist_active_sess_history
 where 1=1
 and sql_id = '&sql_id'
-- and instance_number = ?
-- and session_id = ?
-- and session_serial# = ?
 group by instance_number,
          session_id,
          session_serial#,
          sql_opname,
          sql_id,
          sql_plan_hash_value
 order by 2 desc

--@@  Baselines  @@--
select 
to_char(signature) as signature,
dbms_sql_translator.sql_id(sql_text) as sql_id,
(select replace(plan_table_output,'Plan hash value: ')  
 from dbms_xplan.display_sql_plan_baseline(plan_name => plan_name) 
 where plan_table_output like 'Plan hash value: %') as plan_hash_value,
t.* 
from dba_sql_plan_baselines t
where parsing_schema_name = '&SCHEMA'
select min(snap_id), max(snap_id)
  from dba_hist_active_sess_history
 where sql_id = '&sql_id'
   and sql_plan_hash_value = &phv
;
   
declare
 x number;
begin
x := dbms_spm.load_plans_from_awr( begin_snap=>&begin,end_snap=>&end,
                            basic_filter=>q'# sql_id='&sql_id' and plan_hash_value='&phv' #' );
end;
declare
x number;
begin
  x:= dbms_spm.alter_sql_plan_baseline(plan_name=>'&plan',attribute_name=>'fixed',attribute_value=>'yes');
end;
declare
x number;
begin
  x:= dbms_spm.drop_sql_plan_baseline(plan_name=>'&plan',sql_handle => '&sql_handle');
end;


--@@  crs_flush  @@--
with function crs_flush( c varchar2) return varchar2
is
begin
     sys.dbms_shared_pool.purge( c  , 'C', 65);
     return 'flushed';
end;
select *
  from gv$(cursor(
  select 
     to_number(substr(dbms_session.unique_session_id,9,4),'XXXX') inst_id
   , sql_id 
   , crs_flush(address ||', ' ||hash_value)
from v$sql
where sql_id = '&sql_id'
));


--@@  stale objects in execution plan  @@--
-- https://blogs.oracle.com/optimizer/post/check-sql-stale-statistics
-- Tables
with plan_tables as (
select distinct object_name,object_owner, object_type 
from v$sql_plan 
where object_type like 'TABLE%' 
and   sql_id      = '&sql_id')
select t.object_owner owner,
       t.object_name table_name,
       t.object_type object_type,
       decode(stale_stats,'NO','OK',NULL, 'NO STATS!', 'STALE!') staleness   
from   dba_tab_statistics s,
       plan_tables        t
where  s.table_name = t.object_name
and    s.owner      = t.object_owner
and    s.partition_name is null
and    s.subpartition_name is null
order by t.object_owner, t.object_name;
-- Indexes
with plan_indexes as (
select distinct object_name,object_owner, object_type
from v$sql_plan
where object_type like 'INDEX%'
and   sql_id      = '&sql_id')
select i.object_owner owner,
       i.object_name index_name,
       i.object_type object_type,
       decode(stale_stats,'NO','OK',NULL, 'NO STATS!', 'STALE!') staleness
from   dba_ind_statistics s,
       plan_indexes       i
where  s.index_name = i.object_name
and    s.owner      = i.object_owner
and    s.partition_name is null
and    s.subpartition_name is null
order by i.object_owner, i.object_name;


