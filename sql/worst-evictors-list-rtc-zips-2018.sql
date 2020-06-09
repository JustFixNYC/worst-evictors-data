with head_officer_evictions as (
	select 
		concat(firstname,' ',lastname) as head_officer,

-- HPD "Head Officer" groupings derived through research: 
		case
			when concat(h.firstname,' ',h.lastname) = any('{JULIUS LAMAR, DAVID MATEO, RAFAL MARKWAT}') 
				then 'JULIUS LAMAR, DAVID MATEO (ARETE MANAGEMENT)'
			when concat(h.firstname,' ',h.lastname) = any('{LABE TWERSKI, IABE TWERSKI}') 
				then 'LABE TWERSKI'
			when concat(h.firstname,' ',h.lastname) = any('{LAURENCE GLUCK, LAWRENCE GLUCK, SMAJLJE SRDANOVIC}') 
				then 'LAURENCE GLUCK'
			when concat(h.firstname,' ',h.lastname) = any('{JOEL GOLDSTEIN, IRVING LANGER, IRIVING LANGER, 
															LEIBAL LEDERMAN, AVI DAIVES, AVI DAVIES, HENRY SPITZER, 
															LOUIS LANGER, NAFTALI LEINER, NAFTOLI LEINER}') 
				then 'E&M ASSOC'
			when concat(h.firstname,' ',h.lastname) = any('{RASIM TOSKIC, DAVID RADONCIC, ABIDIN RADONCIC, JOEL WEINER,
															EDWARD SUAZO, EDDIE LJESNJANIN, MARC BARHORIN, DAVID ROSE}') 
				then 'PINNACLE'
			when concat(h.firstname,' ',h.lastname) = any('{STEVEN FINKELSTEIN, STEVE FINKELSTEIN}') 
				then 'STEVEN (STEVE) FINKELSTEIN'
			when concat(h.firstname,' ',h.lastname) = any('{MATTHEW BECKER, MATHEW BECKER, MARC FLYNN}') 
				then 'MATTHEW BECKER'
			when concat(h.firstname,' ',h.lastname) = any('{SCOTT MORGAN, RYAN MORGAN, BROOKE MORGAN, STUART MORGAN}') 
				then 'SCOTT, RYAN, AND BROOKE MORGAN (MORGAN GROUP)'
			when concat(h.firstname,' ',h.lastname) = any('{JACOB HAGER, NAFTALI HAGER, NATALI HAGER}') 
				then 'JACOB AND NAFTALI HAGER (HAGER MANAGEMENT INC)'
			when concat(h.firstname,' ',h.lastname) = any('{MOSHE PILLER, MOSHE PILLLE, SAM ROSEN, SAMUEL BRETTLER}') 
				then 'MOSHE PILLER'
			when concat(h.firstname,' ',h.lastname) = any('{MICHEAL NIAMONITAKIS, MICHAEL NIAMONITAKIS, 
															MIKE NIAMONITAKIS, ANNMARIE BARKER,
															ANTHONY SIRIGOS, DESPINA SIDERATOS, 
															EFTHIMIOS DIMITRIADIS, JAMES D. DIMITRIADES,
															JAMES DIMITRIADES, MICHAEL NEAMONITAKIS}') 
				then 'MICHAEL NIAMONITAKIS'
			when concat(h.firstname,' ',h.lastname) = any('{ELY SINGER, JONAH ROSENBERG, SCOTT MITTEL, ANDY FALKIN, 
															ARI BENEDICT, FAUSTO DIAZ, AVNER SKOCZYLAS, BARRY SENDROVIC, 															JONAH ROSENBERG, ARI BENEDICT, DANIEL BENEDICT}') 
				then 'ELY SINGER, DANIEL BENEDICT (BRG MANAGEMENT LLC)'
			when concat(h.firstname,' ',h.lastname) = any('{DONALD HASTINGS, MAGGIE MCCORMICK, DOUGLAS EISENBERG}') 
				then 'DONALD HASTINGS, DOUGLAS EISENBERG (A&E REAL ESTATE)'
			when concat(h.firstname,' ',h.lastname)= any('{1635 CARROLL LLC,2509 ATLANTIC REALTY LLC,312 EZ REALTY LLC,	
						437 BMW LLC, 491 EQUITIES LLC, 682 MONTGOMERY LLC, DEAN PARK LLC, DRAM LLC, GAN EAST LLC, 
						M WILHELM, MAUNTAUK PARK LLC, MENDY WILHELM, MMS REALTY LLC, PRESIDENT PLAZA LLC, UFARATZTA LLC, 
						YANKY RODMAN}')
				then 'UFARATZTA LLC'
			else concat(h.firstname,' ',h.lastname)
		end as head_officer_group,

-- Supplemental data:
		h.bbl,
		p.zipcode,
		p.unitsres,
		e.evictions,
		coalesce(f.filings,0) as filings,
		coalesce(unitsstab2017, 0) as rs_units 
	from hpd_head_officers h	
	left join (select 
				bbl,
				count(*) as evictions
				from marshal_evictions_18 
				where bbl is not null
				and residentialcommercialind = any('{R,Residential}') 
				group by bbl) e
		on h.bbl = e.bbl
	left join pluto_18v1 p
		on h.bbl = p.bbl
	left join (select 
				bbl,
				sum(evictions) as filings
				from eviction_filings_1315
				where bbl is not null 
				group by bbl) f
		on h.bbl = f.bbl
	left join rentstab_summary rs
		on rs.ucbbl = h.bbl
	where (firstname is not null or lastname is not null)
)

select 
	head_officer_group,
	string_agg(distinct head_officer,', ') as head_officer_individuals,
	
-- Borough-based portfolio calculations 
---- Key: 
---- "assoc_bbls" = list of borough-block-lot codes for other buildings owned by the landlord
---- "portfolio_size" = count of other buildings owned by the landlord
---- "unitsres" = count of residential units owned by the landlord 
---- "evictions" = count of executed 2018 Marshals evictions in properties owned by the landlord
---- "filings" = count of Eviction Filings (from Jan 2013 to June 2015) in properties owned by the landlord
---- "rs_units" = estimate of rent stabilized units owned by the landlord


---- Manhattan RTC Zip Codes:

	array_agg(bbl) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_assoc_bbls,
	count(bbl) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_portfolio_size,
	sum(unitsres) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_unitsres,
	sum(evictions) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_evictions,
	sum(filings) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_filings,
	sum(rs_units) filter (where zipcode = any('{10026, 10027, 10025, 10031}')) MN_rtc_rs_units,


---- Bronx RTC Zip Codes:

	array_agg(bbl) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_assoc_bbls,
	count(bbl) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_portfolio_size,
	sum(unitsres) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_unitsres,
	sum(evictions) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_evictions,
	sum(filings) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_filings,
	sum(rs_units) filter (where zipcode = any('{10457, 10467, 10468, 10462}')) BX_rtc_rs_units,

---- Brooklyn RTC Zip Codes:
	
	array_agg(bbl) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_assoc_bbls,
	count(bbl) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_portfolio_size,
	sum(unitsres) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_unitsres,
	sum(evictions) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_evictions,
	sum(filings) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_filings,
	sum(rs_units) filter (where zipcode = any('{11216, 11221, 11225, 11226}')) BK_rtc_rs_units,

---- Queens RTC Zip Codes:
	
	array_agg(bbl) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_assoc_bbls,
	count(bbl) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_portfolio_size,
	sum(unitsres) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_unitsres,
	sum(evictions) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_evictions,
	sum(filings) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_filings,
	sum(rs_units) filter (where zipcode = any('{11433, 11434, 11373, 11385}')) QN_rtc_rs_units,

---- Staten Island RTC Zip Codes:

	array_agg(bbl) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_assoc_bbls,
	count(bbl) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_portfolio_size,
	sum(unitsres) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_unitsres,
	sum(evictions) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_evictions,
	sum(filings) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_filings,
	sum(rs_units) filter (where zipcode = any('{10302, 10303, 10314, 10310}')) SI_rtc_rs_units,


-- Citywide calculations

	array_agg(bbl) as citywide_assoc_bbls,
	count(bbl) as citywide_portfolio_size,
	sum(unitsres) as citywide_unitsres,
	sum(evictions) as citywide_evictions,
	sum(filings) as citywide_filings,
	sum(rs_units) as citywide_rs_units	
					
from head_officer_evictions 
group by head_officer_group
