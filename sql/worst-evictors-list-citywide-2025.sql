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
	from hpd_contacts c
	left join hpd_registrations_grouped_by_bbl r
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
	array_agg(distinct address order by address) as ll_business_addresses,
	count(distinct address) as count_ll_business_addresses,
	array_agg(distinct assoc_ll_name order by assoc_ll_name) as associated_ll_names,
	count(distinct assoc_ll_name) as count_associated_ll_names,
	array_agg(distinct assoc_bbl order by assoc_bbl) as associated_bbls,
	count(distinct assoc_bbl) as count_associated_bbls
from t2
group by ll_name
),

-- Step 3a: Collapse to one canonical row per portfolio to avoid duplicates.
-- The canonical display name is chosen as the lexicographically-smallest associated name.
hpd_portfolios as (
select
	o.associated_bbls,
	array_agg(distinct n.name order by n.name) as associated_ll_names,
	array_agg(distinct a.address order by a.address) as ll_business_addresses,
	cardinality(o.associated_bbls) as count_associated_bbls,
	count(distinct n.name) as count_associated_ll_names,
	count(distinct a.address) as count_ll_business_addresses,
	min(n.name) as portfolio_name
from hpd_associated_owners o
left join lateral unnest(o.associated_ll_names) as n(name) on true
left join lateral unnest(o.ll_business_addresses) as a(address) on true
group by o.associated_bbls
),

---------------------------------------
-- Join on Evictions Data
---------------------------------------

-- Step 1: Extract distinct groupings of associated bbls from the HPD Associated Owners table
hpd_associated_bbls as (
	select 
		distinct associated_bbls 
	from hpd_portfolios
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
	from marshal_evictions_all
	where bbl is not null
	and residentialcommercialind = any('{R, Residential, RESIDENTIAL}')
	and executeddate >= date '2025-01-01'
	and executeddate < date '2026-01-01'
	group by bbl
),

-- Step 3b: Count class B/C HPD violations by bbl (2025)
hpd_violations_bc_by_bbl as (
	select
		bbl,
		count(*) as hpd_violations_bc
	from hpd_violations
	where bbl is not null
		and class = any('{B,C}')
		and inspectiondate >= date '2025-01-01'
		and inspectiondate < date '2026-01-01'
	group by bbl
),

-- Step 3c: Count HPD complaints by bbl (2025)
hpd_complaints_by_bbl as (
	select
		bbl,
		count(*) as hpd_complaints
	from hpd_complaints_and_problems
	where bbl is not null
		and receiveddate >= date '2025-01-01'
		and receiveddate < date '2026-01-01'
	group by bbl
),

-- Step 4: Append additional data to associated bbls in unnested table 
evictions_by_bbl_with_data as (
	select
		associated_bbls,
		bbl,
		coalesce(evictions,0) evictions,
		coalesce(filings,0) filings,
		coalesce(hpd_violations_bc,0) hpd_violations_bc,
		coalesce(hpd_complaints,0) hpd_complaints,
		coalesce(p.unitsres,0) unitsres,
		coalesce(r.uc2024,0) unitsstab2024
	from hpd_associated_bbls_unnested e
	left join evictions_by_bbl using(bbl)
	left join hpd_violations_bc_by_bbl using(bbl)
	left join hpd_complaints_by_bbl using(bbl)
	left join 
		(
			select
				a.bbl,
				count(distinct i.indexnumberid) as filings
			from oca_index i
			left join oca_addresses_with_bbl a using(indexnumberid)
			where i.fileddate >= date '2025-01-01'
				and i.fileddate < date '2026-01-01'
				and i.classification = any('{Holdover,Non-Payment}')
				and i.propertytype = 'Residential'
				and a.bbl is not null
			group by a.bbl
		)
		eviction_filings_by_bbl	using(bbl)
	left join pluto_25v2_1 p using(bbl)
	left join rentstab_v2 r on bbl = ucbbl
),



-- Step 5: Join evictions counts to each unnested bbl, and then regroup by associations
hpd_associated_bbls_with_evictions as (
	select 
		a.associated_bbls,
		sum(evictions) as total_evictions_2025,
		sum(filings) as total_filings_2025,
		sum(hpd_violations_bc) as total_hpd_violations_bc_2025,
		sum(hpd_complaints) as total_hpd_complaints_2025,
		sum(unitsres) as total_unitsres,
		sum(unitsstab2024) as total_rs_units_24
	from evictions_by_bbl_with_data a
	group by a.associated_bbls
)

-- Step 6: Rejoin data back with HPD associated owners table
select 
	total_evictions_2025,
	total_hpd_violations_bc_2025,
	total_hpd_complaints_2025,
	total_unitsres,
	total_filings_2025,
	case when (total_unitsres > 0)   
		then round(total_filings_2025::numeric/total_unitsres::numeric,1)
		else 0 end filings_per_family,
	total_rs_units_24,
	case when (total_unitsres > 0)
		then round(total_rs_units_24::numeric/total_unitsres::numeric * 100,0)
		else 0 end pct_rs,
	a.portfolio_name as ll_name,
	a.ll_business_addresses,
	a.count_ll_business_addresses,
	a.associated_ll_names,
	a.count_associated_ll_names,
	a.associated_bbls,
	a.count_associated_bbls
from hpd_portfolios a
left join hpd_associated_bbls_with_evictions e 
	on a.associated_bbls = e.associated_bbls
order by total_evictions_2025 desc nulls last
limit 150;

