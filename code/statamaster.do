/*~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	Author:		Daniel Perez
	Title: 		mfg_premium_josh.do
	Date: 		03/17/2022
	Created by: 	Daniel Perez
	
	Purpose:    	Estimate manufacturing union premium

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/

********* Preamble *********
clear all
set more off

********* Directories *********
global base "/projects/dperez/mfg_wage_premium_josh/"
global code ${base}code/
global output ${base}output/

********* Import CPI  *********
sysuse cpi_annual, clear
keep year cpiurs
tempfile cpi
save `cpi'

********* Load CPS ORG sample *********
load_epiextracts, begin(2010m1) end(2021m12) sample(ORG) keep(year month orgwgt lfstat emp selfemp selfinc manuf wage age female educ gradeatn wbho wbhao region)

*merge cpi to cps
merge m:1 year using `cpi', keep(3) nogenerate

*adjust wages to 2021 values
sum year
local maxyear =`r(max)'
sum cpiurs if year ==`maxyear'
local basevalue =`r(mean)'

*adjust hourly wages to 2021 dollars
gen realwage = wage * [`basevalue'/cpiurs]
label var realwage "Hourly wages in real 2021 dollars"

gen wgt = orgwgt/12

*generate alt selfemp/selfinc indicators
gen byte not_selfemp = .
replace not_selfemp = 1 if selfemp==0 | selfemp==.
replace not_selfemp = 0 if selfemp==1

gen byte not_selfinc = .
replace not_selfinc = 1 if selfinc==0 | selfinc==.
replace not_selfinc = 0 if selfinc == 1

*keep 16+ and employed only in may data as somehow there are unemployed union members
keep if age >= 16
keep if emp == 1
keep if not_selfemp==1
keep if not_selfinc==1

* log wage used in regressions
gen lnwage = log(realwage)

*age bins 
gen byte agebin = .
replace agebin = 1 if age>=16 & age <=24
replace agebin = 2 if age>=25 & age <=34
replace agebin = 3 if age>=35 & age <=44
replace agebin = 4 if age>=45 & age <=54
replace agebin = 5 if age>=55 & age <=64
replace agebin = 6 if age >=65

{
lab var agebin "Age bins"
#delimit ;
lab def agebin
1 "16-24"
2 "25-34"
3 "35-44"
4 "45-54"
5 "55-64"
6 "65&up"
;
#delimit cr
lab val agebin agebin
}

*add labels
numlabel, add

tempfile cps 
save `cps'

use `cps', clear
local counter = 0
forvalues j=2010/2021{
	local counter = `counter' + 1
	eststo reg_`j': reg lnwage i.manuf i.female i.wbho i.agebin i.educ i.region [pw=wgt] if year == `j'
	if `counter' == 1 local wage_regs reg_`j'
	else local wage_regs `wage_regs' reg_`j'
}
estout `wage_regs' using ${output}wage_regs.csv, cells(b) replace
/*this outputs the macro, which is a list of stored reg output and renames coefficients*/

use `cps', clear
keep if educ<4
local counter = 0
forvalues j=2010/2021{
	local counter = `counter' + 1
	eststo reg_`j': reg lnwage i.manuf i.female i.wbho i.agebin i.educ i.region [pw=wgt] if year == `j'
	if `counter' == 1 local wage_regs_lt4yd reg_`j'
	else local wage_regs_lt4yd `wage_regs_lt4yd' reg_`j'
}
estout `wage_regs_lt4yd' using ${output}wage_regs_lt4yd.csv, cells(b) replace
/*this outputs the macro, which is a list of stored reg output and renames coefficients*/

use `cps', clear
keep if educ>=4
local counter = 0
forvalues j=2010/2021{
	local counter = `counter' + 1
	eststo reg_`j': reg lnwage i.manuf i.female i.wbho i.agebin i.educ i.region [pw=wgt] if year == `j'
	if `counter' == 1 local wage_regs_baplus reg_`j'
	else local wage_regs_baplus `wage_regs_baplus' reg_`j'
}
estout `wage_regs_baplus' using ${output}wage_regs_baplus.csv, cells(b) replace
/*this outputs the macro, which is a list of stored reg output and renames coefficients*/
