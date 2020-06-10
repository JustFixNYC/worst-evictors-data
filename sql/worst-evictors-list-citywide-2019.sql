---------------------------------------
-- Create HPD Associated Owners table
---------------------------------------


-- Step 1: Generate list of HeadOfficers and Individual Owners, with their business addresses and bbls
with t1 as (
	select 
		case 
			-- Use Organizer-driven grouping for Pinnacle Group:
			when concat(firstname,' ',lastname) = any('{"DAVID ROSE","EDDIE LJESNJANIN","EDWARD SUAZO","MARC BARHORIN","ABDIN RADONCIC","ABIDIN RADONCIC","DAVID RADONCIC","DAVID RADONIC","ELINOR ARZT","RASIM TOSKIC"}') then 'PINNACLE' 
			else upper(concat(firstname,' ',lastname)) end as ll_name,
		upper(
			concat(
				businesshousenumber,' ',
				businessstreetname,' ',
				businessapartment,', ',
				businesscity,', ',
				businessstate
				)
			) 
		as address,
		bbl
	from hpd_contacts_dec_19 c
	left join hpd_registrations_grouped_by_bbl_dec_19 r
		on r.registrationid = c.registrationid
	where type = any('{HeadOfficer,IndividualOwner,CorporateOwner}')
		-- filter out null or invalid values: 
		and (businesshousenumber is not null OR businessstreetname is not null)
		and length(concat(businesshousenumber,businessstreetname)) > 2
		and (firstname is not null OR lastname is not null)
	group by ll_name, address, bbl
),

-- Step 2: Join Head Officers/Owners table with itself, matching owner names and bbls by common business address
t2 as (
	select 
		t1.*,
		t1_duplicate.ll_name as assoc_ll_name,
		t1_duplicate.bbl as assoc_bbl
	from t1
	left join t1 as t1_duplicate on t1_duplicate.address = t1.address
),

-- Step 3: Group table by starting owner name, 
-- creating an array of associated business addresses, associated owner names, and associated bbls that share those business addresses
hpd_associated_owners as (
select 
	ll_name,
	array_agg(distinct address) as ll_business_addresses,
	count(distinct address) as count_ll_business_addresses,
	array_agg(distinct assoc_ll_name) as associated_ll_names,
	count(distinct assoc_ll_name) as count_associated_ll_names,
	array_agg(distinct assoc_bbl) as associated_bbls,
	count(distinct assoc_bbl) as count_associated_bbls
from t2
group by ll_name
),

---------------------------------------
-- Join on Evictions Data
---------------------------------------

-- Step 1: Extract distinct groupings of associated bbls from the HPD Associated Owners table
hpd_associated_bbls as (
	select 
		distinct associated_bbls 
	from hpd_associated_owners
),

-- Step 2: Unnest BBLs from associated_bbls arrays
hpd_associated_bbls_unnested as (
	select 
		associated_bbls,
		unnest(associated_bbls) as bbl
	from hpd_associated_bbls
), 

-- Step 3: Make helper table to count residential evictions by bbl
evictions_by_bbl as (
	select 
		bbl,
		count(*) as evictions
	from marshal_evictions_19
	where bbl is not null
	and residentialcommercialind = any('{R, Residential, RESIDENTIAL}')
	group by bbl
),

-- Step 4: Append additional data to associated bbls in unnested table 
evictions_by_bbl_with_data as (
	select
		associated_bbls,
		bbl,
		coalesce(evictions,0) evictions,
		coalesce(filings,0) filings,
		coalesce(p.unitsres,0) unitsres,
		coalesce(r.uc2018,0) unitsstab2018
	from hpd_associated_bbls_unnested e
	left join evictions_by_bbl using(bbl)
	left join 
		(select bbl, sum(f.evictions) filings from eviction_filings_1315 f group by bbl) 
		eviction_filings_by_bbl	using(bbl)
	left join pluto_19v1 p using(bbl)
	left join rentstab_v2 r using(bbl)
),



-- Step 5: Join evictions counts to each unnested bbl, and then regroup by associations
hpd_associated_bbls_with_evictions as (
	select 
		a.associated_bbls,
		sum(evictions) as total_evictions_19,
		sum(filings) as total_filings_1315,
		sum(unitsres) as total_unitsres,
		sum(unitsstab2018) as total_rs_units_18
	from evictions_by_bbl_with_data a
	group by a.associated_bbls
)

-- Step 6: Rejoin data back with HPD associated owners table
select 
	total_evictions_19,
	total_unitsres,
	total_filings_1315,
	case when (total_unitsres > 0)   
		then round(total_filings_1315::numeric/total_unitsres::numeric,1)
		else 0 end filings_per_family,
	total_rs_units_18,
	case when (total_unitsres > 0)
		then round(total_rs_units_18::numeric/total_unitsres::numeric * 100,0)
		else 0 end pct_rs,
	a.*
from hpd_associated_owners a
left join hpd_associated_bbls_with_evictions e 
	on a.associated_bbls = e.associated_bbls
order by total_evictions_19 desc nulls last
limit 150;

