clear
set more off
capture log close

log using "C:\Users\k1214788\OneDrive - King's College London\social determin folder from server\PhD Project\kch_pruh", replace
cd "C:\Users\k1214788\OneDrive - King's College London\social determin folder from server\PhD Project\kch_pruh"

global raw "raw"
global work "work"
global output "output"

set scheme s1color

/********************data prep and cleaning********************************/
clear
insheet using "$raw\PRUH extracted 30.06.20.csv"
gen hosp_id=1
order hosp_id
drop pseudoid2
save "$raw\PRUH extracted 30.06.20.dta", replace

clear
insheet using "$raw\kch extracted 30.06.20.csv"
gen hosp_id=2
order hosp_id
drop usethiscode
save "$raw\kch extracted 30.06.20.dta", replace
append using "$raw\PRUH extracted 30.06.20.dta"

label define hosp_id 1 PRUH 2 KCH
label values hosp_id hosp_id

save "$work\kch and pruh extracted 30.06.20.dta", replace

clear
use "$work\kch and pruh extracted 30.06.20.dta"

/**DROP SOME ROWS - read notes**/

/*contact id is essential for later analysis - drop those without*/
/*many are referrals not accepted*/
/*some are teamreferrals - rows containing a team referral id have NO time attached - the time is being recorded on another record*/
drop if contactid==0 

/*flag, visually inspect and then drop duplicates*/
/*dataset is at contact level - i.e. contacts are unique, there should be no duplicates on pseudoid contactid vars
contact level duplicates arise when info is updated within the same contact...
for most variables the info is duplicated exactly, variation is mostly due to changes to: diagnosisrecordeddate diagnosisupdateddate maindiagnosis secondarydiagnosis..
and to a lesser extent other string vars inclu: maritalstatus ethnicity religion livesalone
We need to delete duplicate contacts, first fill down/up gaps so new info contained in a dup record isnt lost
...where different values are recorded in a dup (examples in maritalstatus ethnicity religion livesalone), no definitive way to tell which entry is more valid...
...we will first take the last entry as the most valid, and then take earlier info*/
duplicates tag pseudoid contactid, gen (dupflag)
tab dupflag
preserve
drop id diagnosisrecordeddate diagnosisupdateddate maindiagnosis secondarydiagnosis maritalstatus ethnicity religion livesalone gender preferredlanguage interpreter disability 
duplicates tag, gen (dupflag2)
tab dupflag2
restore
sort dupflag contactid 
/*order all the numericals first*/
ds , has(type numeric)
order `r(varlist)'
/*fill up and down before dup drop (take most recent record first) - apply to all vars (it wont effect those without duplicates and gaps)*/
order pseudoid contactid id dupflag
/*up*/
gsort pseudoid contactid -id
/*numericals*/
foreach var of varlist clinicalcontacttimepatient-eolcrentry{
bys pseudoid contactid: replace `var'=`var'[_n-1] if `var'==.
}
/*strings*/
foreach var of varlist updated-pallcaresocialworkreferral{
bys pseudoid contactid: replace `var'=`var'[_n-1] if `var'==""
}
/*down*/
gsort pseudoid contactid id
/*numericals*/
foreach var of varlist clinicalcontacttimepatient-eolcrentry{
bys pseudoid contactid: replace `var'=`var'[_n-1] if `var'==.
}
/*strings*/
foreach var of varlist updated-pallcaresocialworkreferral{
bys pseudoid contactid: replace `var'=`var'[_n-1] if `var'==""
}
/*delete dups*/
gsort pseudoid contactid -id
duplicates drop pseudoid contactid, force /*3079 obs deleted*/
drop dupflag

/*drop if the referral was not accepted - 98% are accepted*/
browse pseudoid contactid referralaccepted clinicalcontacttimepatient- clinicalcontacttimeextprof
/*N means referral not accepted, note that they do have time attached includinng in some cases clinical-patient time...
...but we know that they were not accepted so drop
...also some "" and "A" - these also have time attached and may be a system/human error that fails to apply the "Y", so keep in*/ 
drop if referralaccepted=="N" 

/*drop if no activity time is attached*/
/*very small numbers with no time - usually just 1 or 2 cases*/
gen flag=1 if (clinicalcontacttimepatient==. & clinicalcontacttimefamily==. & clinicalcontacttimeintprof==. & clinicalcontacttimeextprof==. & admintimepatient==. & admintimefamily==. & admintimeintprof==. & admintimeextprof==.)
tab flag, mi /*3 rows*/
drop if flag==1
drop flag

/*drop based on referral type - i.e. only keep inpatients*/
/*96% are 'hospital support'. we are dropping small number of referrals for bereavement, community and outpatient*/
keep if referralto=="Hospital Support" | referralto=="Inpatient Service"

/*FORMAT DATE VARS*/
/*datestamp var is auto generated from the referral date unless referral date is blank then the contact date is taken*/
/*in some cases may need to work with the original referral and contact dates - so format these as well*/
/*format the datestamp*/
gen datestamp2=substr(datestamp,1, 10) 
order datestamp2
gen datestamp3=date(datestamp2,"DMY")
order datestamp3
format datestamp3 %tddd/NN/CCYY
drop datestamp datestamp2

/*format the referral date and the contact date*/
gen referralreceiveddate2=substr(referralreceiveddate,1, 10) 
order referralreceiveddate2
gen referralreceiveddate3=date(referralreceiveddate2,"DMY")
format referralreceiveddate3 %tddd/NN/CCYY
drop referralreceiveddate referralreceiveddate2

gen contactdate2=substr(contactdate,1, 10) 
order contactdate2
gen contactdate3=date(contactdate2,"DMY")
format contactdate3 %tddd/NN/CCYY
drop contactdate contactdate2

/*format decease and discharge dates*/
gen deceaseddate2=substr(deceaseddate,1, 10)
gen deceaseddate3=date(deceaseddate2, "DMY")
format deceaseddate3 %tddd/NN/CCYY
drop deceaseddate deceaseddate2

gen dischargedate2=substr(dischargedate,1, 10)
gen dischargedate3=date(dischargedate2, "DMY")
format dischargedate3 %tddd/NN/CCYY
drop dischargedate dischargedate2

/*STRUCTURE VARS*/
/*fix a small prob with syst generated contactnumber*/
/*flag referrals with no contactnumber 1*/
sort pseudoid referralid contactnumber, stable
browse pseudoid referralid contactnumber 
bys pseudoid referralid: egen mincontact=min(contactnumber)
tab mincontact
/*13 referrals that dont start with contact 1 - ///
not a problem with the date range of the extract cutting off the first visit - i think just a glitch/system error///
the contactnumber is syst generated - i will correct for this small number of cases*/
bys pseudoid referralid: replace contactnumber=_n if mincontact!=1
sort pseudoid referralid contactnumber, stable
bys pseudoid referralid: egen mincontact2=min(contactnumber)
drop mincontact 

/*there is also a problem with the syst generated referralnumber - its not sequential with date in all cases (see 83dfd1 for example)*/
/*gen new referral number var, counting only referrals accepted*/
/*using option stable to address any duplicates*/
sort pseudoid referralid referralnumber datestamp3 contactnumber, stable
browse pseudoid referralid referralnumber datestamp3 contactnumber
sort pseudoid referralid datestamp3 contactnumber, stable
gen referralnumber2=1 if contactnumber==1
sort pseudoid referralnumber2 datestamp3, stable
bys pseudoid: replace referralnumber2=_n if referralnumber2==1
sort pseudoid referralid datestamp3 contactnumber, stable
bys pseudoid referralid: replace referralnumber2=referralnumber2[_n-1] if referralnumber2==.
/*flag and visually inspect the differences*/
gen flag=1 if referralnumber2!=referralnumber
drop flag 
drop referralnumber /*to avoid confusion*/

/*generate max number of referrals and max number of contacts at patient level*/
browse pseudoid referralid referralnumber2 contactnumber 
sort pseudoid referralid referralnumber2 contactnumber, stable 
bysort pseudoid referralid: egen max_contacts=max(contactnumber)
bysort pseudoid: egen max_referrals=max(referralnumber2)

/*flag re-referrals*/
recode max_referrals (1=0) (2/13=1), gen (re_referred)
tab max_referrals re_referred, mi

/*gen contacts count*/
gen contacts=1

/*diagnosis*/
/*NB most cases have either cancer and noncancer diagnosis - for small number who have both, coding priority order is (dementia cardio resp) cancer other*/
encode diagnosiscancermds, gen(diagnosiscancermds2)
label list diagnosiscancermds2
encode diagnosisnoncancermds, gen(diagnosisnoncancermds2)
label list diagnosisnoncancermds2
gen diagnosis=5
replace diagnosis=1 if diagnosiscancermds2!=.
replace diagnosis=2 if diagnosisnoncancermds2==5 | diagnosisnoncancermds2==6
replace diagnosis=3 if diagnosisnoncancermds2==10 | diagnosisnoncancermds2==11 | ///
diagnosisnoncancermds2==16 | diagnosisnoncancermds2==17 | diagnosisnoncancermds2==19
replace diagnosis=4 if diagnosisnoncancermds2==3 | diagnosisnoncancermds2==4
replace diagnosis=. if diagnosisnoncancermds2==. & diagnosiscancermds2==. 
label define diagnosis 1 "cancer" 2 "dementia" 3 "cardiovascular" 4 "respiratory" 5 "other"
label values diagnosis diagnosis
tab diagnosis, mi
tab diagnosiscancermds2 diagnosis, mi
tab diagnosisnoncancermds2 diagnosis, mi

/*recode lives alone*/
encode livesalone, gen(livesalone2)
label list livesalone2
recode livesalone2 (3=2) (2=.)
label define livesalone2 1 "not living alone" 2 "living alone", replace
label values livesalone2 livesalone2
tab livesalone livesalone2, mi

/*destring ipos items for use later*/
destring  pospain - pospracticalproblems, force replace

/*encode phase*/
encode phase, gen(phase2)
label list phase2
recode phase2 (2=1) (5=2) (1=3) (3=4) (4=.)
label define phase2 1 "stable" 2 "unstable" 3 "deteriorating" 4 "dying", replace
label values phase2 phase2
tab phase phase2, mi

/*encode gender*/
encode gender, gen(gender2)
label list gender2
recode gender2 (3=.)
tab gender gender2, mi

/*encode and recode marstat*/
encode maritalstatus, gen(maritalstatus2)
label list maritalstatus2
recode maritalstatus2 (1 3 6 =1) (2 7 8 9 10 = 2) (5 = 3) (4 =.)
label define maritalstatus2 1 "married or partnered" 2 "single, seperated or widowed" 3 "other", replace
label values maritalstatus2 maritalstatus2
tab maritalstatus maritalstatus2, mi

/*encode and recode ethnicity*/
/*using mds (minimum dataset cats) - concern re how consistently applied these codes are...
...when you look at the raw data and lots of different codes are being used*/
gen ethnicity2=substr(ethnicity, 1, 1)
tab ethnicity, miss
tab ethnicity2, miss
gen ethnicity3=ethnicity2
replace ethnicity3="X" if ethnicity2==""
encode ethnicity3, gen(ethnicity4)
label list ethnicity4
tab ethnicity3, miss
tab ethnicity4, miss
label define ethnicity4 1 "White British" 2 "White Irish" 3 "Other White" ///
4 "White & Black Caribbean" 5 "White & Black African" 6 "White and Asian" 7 "Other mixed" 8 "Indian" 9 "Pakistani" ///
10 "Bangladeshi" 11 "Other Asian" 12 "Caribbean" 13 "African" 14 "Other Black" 15 "Chinese" 16 "Other" 17 "Miss-coded" 18 "Not stated" , replace
label values ethnicity4 ethnicity4
tab ethnicity ethnicity4, mi
recode ethnicity4 (17 18 = .)
tab ethnicity4, mi
drop ethnicity2 ethnicity3 
/*further aggregate*/
recode ethnicity4 (1=1) (2 3 =2) (4 5 12 13 14 =3) (6 8 9 10 11 =4) (7 15 16 =5), gen(ethnicity5)
label define ethnicity5 1 "white british" 2 "white other" 3 "black" 4 "asian" 5 "other"
label values ethnicity5 ethnicity5
tab ethnicity ethnicity5, mi
tab ethnicity4 ethnicity5, mi

/*missing as cat6*/
recode ethnicity5 (.=99), gen(ethnicity6)
label values ethnicity6 ethnicity5
/*missing for lives alone*/
recode livesalone2 (.=99), gen(livesalone3)
label values livesalone3 livesalone2

tab age, mi /*NB some age above 112 (oldest person on record in UK) not plausible*/
replace age=. if age>112
recode age (0/49=.) (50/64=1) (65/84=2) (85/99=3) (100/162=4), gen(age_cats)
label define age_cats 1 "50-64" 2 "65-84" 3 "85-99" 4 "100+"
label values age_cats age_cats
tab age age_cats, mi

/*referral outcome*/
tab referralstatus, miss
tab dischargeto, miss
tab dischargeto referralstatus, miss
gen referraloutcome=.
replace referraloutcome=1 if dischargeto=="Patient/carer/relative home" 
replace referraloutcome=2 if dischargeto=="Care Home" 
replace referraloutcome=3 if dischargeto=="Hospice/specialist palliative care unit" | dischargeto=="Hospice (CMH)" | dischargeto=="Other hospice (any other non-CMH hospice)"
replace referraloutcome=4 if dischargeto=="Hospital (acute)" | dischargeto=="Hospital (community)" | dischargeto=="Discharged from team" | dischargeto=="Other" 
replace referraloutcome=4 if referraloutcome==. & referralstatus=="Discharged"
replace referraloutcome=5 if referralstatus=="Deceased"
label define referraloutcome 1 "home" 2 "care home" 3 "hospice" 4 "discharged" 5 "deceased", replace 
label values referraloutcome referraloutcome
label var referraloutcome "destination at end of spell"
tab referraloutcome, mi
tab dischargeto referraloutcome, mi
tab referralstatus referraloutcome, mi
/*check against placeofdeath var and recode any inconsistencies*/
tab referraloutcome placeofdeath, mi
replace referraloutcome=1 if placeofdeath=="Home"
replace referraloutcome=3 if placeofdeath=="Hospice or Specialist Palliative care unit" 
replace referraloutcome=4 if placeofdeath=="Community Hospital"
/*further aggregate*/
recode referraloutcome (1 2 3 = 1) (4=2) (5=3), gen (referraloutcome2)
label define referraloutcome2 1 "home/hospice/carehome" 2 "discharged" 3 "deceased"
label values referraloutcome2 referraloutcome2
tab referraloutcome referraloutcome2, mi

/*akps*/
encode akps, gen(akps2)
label list akps2
recode akps2 (1=0) (2=10) (3=100) (4=20) (5=30) (6=40) (7=50) (8=60) (9=70) (10=80) (11=90), gen(akps3)
tab akps3, mi

/*IMPUTE PCOMS*/
/*generate a time between contacts var*/
sort pseudoid referralid contactnumber, stable
bys pseudoid referralid: gen time_between=contactdate3-contactdate3[_n-1]
replace time_between=0 if contactnumber==1
browse pseudoid referralid contactdate3 time_between
/*check that no dups exist for id, referralid and contact num*/
duplicates tag pseudoid referralid contactnumber, gen(dupflag)
/*there is one anomaly dup, not clear why, could be system error but only seems to effect one case so just manually change the contact num*/
replace contactnumber=4 if contactid==4690059
/*gen phase change*/
/*the dataset contains an auto variable indicating phase change but this does not seem relaible*/
gen phase_change=0
replace phase_change=1 if contactnumber==1 & phase2!=.
sort pseudoid referralid contactnumber, stable
bys pseudoid referralid: replace phase_change=1 if phase2!=phase2[_n-1] & phase2!=.
drop phasechange /*the auto generated version, to avoid confusion*/
/*apply phase number to all contacts within phase*/
gen phasenumber=.
sort pseudoid referralid phase_change contactnumber, stable
bys pseudoid referralid phase_change: replace phasenumber=_n if phase_change==1
sort pseudoid referralid contactnumber, stable
bys pseudoid referralid: replace phasenumber=phasenumber[_n-1] if phasenumber==.
/*also gen max number of phases for later descriptives*/
sort pseudoid referralid phasenumber contactnumber, stable
bys pseudoid referralid: egen max_phase=max(phasenumber)
/*gen time since phase change for the impute*/
sort pseudoid referralid contactnumber, stable
gen phasechangedate=contactdate3 if phase_change==1
bys pseudoid referralid: replace phasechangedate=phasechangedate[_n-1] if phasechangedate==.
bys pseudoid referralid: gen dayssincephase=contactdate3-phasechangedate
/*see how many rows we need to apply the imputation to - i.e highest contact number within 3 days*/
sort dayssincephase contactnumber 
tab contactnumber if dayssincephase<4
/*highest number of contacts within 3 days is 67 - use this in the loop later*/

/*impute missing akps and ipos at phase change, from data collected later within the same phase, up to 3 days after phase change
...NB only data collected after phase change (within same phase, within 3 days) is allowed, not before phase change because this would not be part of same phase*/

browse pseudoid referralid contactnumber phase_change dayssince akps3 
gsort pseudoid referralid phasenumber contactnumber
foreach var of varlist akps3 pospain - pospracticalproblems{
gen `var'_imp=`var'
}
forvalues i = 1/67 {
foreach var of varlist akps3 pospain - pospracticalproblems {
    	by pseudoid referralid phasenumber: replace `var'_imp=`var'_imp[_n+`i'] if phase_change==1 & `var'_imp[_n+`i']!=. & dayssince[_n+`i']<4    
}
} 

/*drop id to avoid confusion - this was generated during data extraction, not needed*/
drop id

/*sum total clinical time with patient for each phase - to highlight phases with no clinical/patient time*/
/*we would not expect other pcoms, partic ipos to be collected for these*/
sort pseudoid referralid phasenumber contactnumber
bys pseudoid referralid phasenumber: egen phasepatienttime=sum(clinicalcontacttimepatient)

/*create total contact time vars - at referral level and aggregate some cats*/
sort pseudoid referralid phasenumber contactnumber
bys pseudoid referralid: egen clinicaltimepatient_r=sum(clinicalcontacttimepatient) 
bys pseudoid referralid: egen clinicaltimefamily_r=sum(clinicalcontacttimefamily)
egen profstimetotal_r=rowtotal(clinicalcontacttimeintprof clinicalcontacttimeextprof) 
bys pseudoid referralid: egen clinicaltimeprofs_r=sum(profstimetotal_r) 
egen admintime_r=rowtotal(admintimepatient admintimefamily admintimeintprof admintimeextprof)
bys pseudoid referralid: egen alladmintime_r=sum(admintime_r) 
egen clinicaltime_r=rowtotal(clinicalcontacttimepatien clinicalcontacttimefamily clinicalcontacttimeintprof clinicalcontacttimeextprof)
bys pseudoid referralid: egen allclinicaltime_r=sum(clinicaltime_r)
egen allclinandadmintime_r=rowtotal(admintimepatient admintimefamily admintimeintprof admintimeextprof clinicalcontacttimepatien clinicalcontacttimefamily clinicalcontacttimeintprof clinicalcontacttimeextprof)
bys pseudoid referralid: egen alltime_r=sum(allclinandadmintime_r)

label var clinicaltimepatient_r "clinical patient time, referral level"
label var clinicaltimefamily_r "clinical family time, referral level"
label var clinicaltimeprofs_r "clinical prof time, referral level"
label var alladmintime_r "all admin time, referral level"
label var allclinicaltime_r "all clinical time, referral level"
label var alltime_r "all time, referral level"

egen allclinandadmintime_pt=rowtotal(admintimepatient admintimefamily admintimeintprof admintimeextprof clinicalcontacttimepatien clinicalcontacttimefamily clinicalcontacttimeintprof clinicalcontacttimeextprof)
bys pseudoid: egen alltime_pt=sum(allclinandadmintime_pt)
label var alltime_pt "all time, patient level"

/*link imd to lsoa*/
/*gen second lsoa from the second attempt to link*/
foreach var of varlist lsoacode1 lsoacode2 lsoacode3 lsoacode4 {
replace `var'="" if `var'=="#N/A"
}
gen lsoa11 = lsoacode1
replace lsoa11 = lsoacode2 if lsoa11==""
replace lsoa11 = lsoacode3 if lsoa11==""
replace lsoa11 = lsoacode4 if lsoa11==""
preserve
duplicates drop pseudoid, force
tab gender2, mi
tab gender2 if lsoa11=="", mi
restore
/*180 of 9721 patients have missing lsoa*/
sort lsoa11
save "$work\kch and pruh 2016 to 2019 deprivation eval.dta", replace
clear
insheet using "$raw\2019_IMD and IDAOPI.csv"
keep lsoacode2011 lsoaname2011 localauthoritydistrictcode2019 localauthoritydistrictname2019 indexofmultipledeprivationimdran indexofmultipledeprivationimddec incomedeprivationaffectingolderp v10
sort lsoacode2011
rename lsoacode2011 lsoa11
save "$raw\2019_IMD and IDAOPI.dta", replace

merge 1:m lsoa11 using "$work\kch and pruh 2016 to 2019 deprivation eval.dta"
browse _merge *lsoa*
drop if _merge==1

rename v10 idaopi_dec
rename incomedeprivationaffectingolderp idaopi_rank
rename indexofmultipledeprivationimdran imd_rank
rename indexofmultipledeprivationimddec imd_dec
recode imd_dec (1 2=1) (3 4=2) (5 6=3) (7 8=4) (9 10=5), gen(imd_quint)
recode idaopi_dec (1 2=1) (3 4=2) (5 6=3) (7 8=4) (9 10=5), gen(idaopi_quint)
destring imd_rank idaopi_rank, ignore(",") replace

save "$work\kch and pruh 2016 to 2019 deprivation eval.dta", replace

/*create referral level dataset - first referral first contact only*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval.dta"
sort pseudoid referralid contactnumber
duplicates drop pseudoid referralid, force
keep if referralnumber==1
drop if allclinicaltime_r==0

/*drop if <60*/
drop if age<60

/*and drop those with missing imd*/
/*n=7963 - 103 (1.29%) missing imd*/
tab idaopi_quint, mi
drop if idaopi_quint==.
/*n=7860*/

/*create the subscale scores - from FIRST RECORDED ipos within 3 days and in same phase (complete case)*/
egen physical3 = rowtotal (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp) 
egen emotional3 = rowtotal (posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp)
egen practical3 = rowtotal (possharefeelings_imp posinformation_imp pospracticalproblems_imp)
egen totalipos3 = rowtotal (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp ///
posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp ///
possharefeelings_imp posinformation_imp pospracticalproblems_imp)

egen physicalmiss3 = rowmiss (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp) 
egen emotionalmiss3 = rowmiss (posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp)
egen practicalmiss3 = rowmiss (possharefeelings_imp posinformation_imp pospracticalproblems_imp)
egen totaliposmiss3 = rowmiss (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp ///
posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp ///
possharefeelings_imp posinformation_imp pospracticalproblems_imp)

replace physical3 =. if physicalmiss3>0
replace emotional3 =. if emotionalmiss3>0
replace practical3 =. if practicalmiss3>0
replace totalipos3 =. if totaliposmiss3>0

/*impute based on the MEDIAN for cases with 50% or more complete ipos*/
/*gen median of non missing*/
egen physicalmed = rowmedian (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp) 
egen emotionalmed = rowmedian (posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp)
egen practicalmed = rowmedian (possharefeelings_imp posinformation_imp pospracticalproblems_imp)

foreach var of varlist pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp  ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp ///
posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp ///
possharefeelings_imp posinformation_imp pospracticalproblems_imp {
gen `var'_mdim=`var'
}
foreach var of varlist pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp {
replace `var'_mdim = physicalmed if  `var'_mdim==. & physicalmiss3<6
}
foreach var of varlist posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp {
replace `var'_mdim = emotionalmed if `var'_mdim==. & emotionalmiss3<3
}
foreach var of varlist possharefeelings_imp posinformation_imp pospracticalproblems_imp {
replace `var'_mdim = practicalmed if `var'_mdim==. & practicalmiss3<3
}
/*create the subscale scores*/
egen physical_mdim = rowtotal (pospain_imp_mdim possob_imp_mdim posweakness_imp_mdim posnausea_imp_mdim posvomiting_imp_mdim ///
pospoorappetite_imp_mdim posconstipation_imp_mdim possoredrymouth_imp_mdim posdrowsiness_imp_mdim pospoormobility_imp_mdim) 
egen emotional_mdim = rowtotal (posanxious_imp_mdim posfamilyanxiety_imp_mdim posdepressed_imp_mdim posatpeace_imp_mdim)
egen practical_mdim = rowtotal (possharefeelings_imp_mdim posinformation_imp_mdim pospracticalproblems_imp_mdim)

replace physical_mdim =. if physicalmiss3>5
replace emotional_mdim =. if emotionalmiss3>2
replace practical_mdim =. if practicalmiss3>2

save "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta", replace

/********************end of initial prep*******************************************/


/*******************************************************************************************************/
/*MULTIPLE IMPUTATION of the missing ipos data*/
/*useful guidance : https://www.ssc.wisc.edu/sscc/pubs/stata_mi_impute.htm*/

clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"

/*MI SET THE DATA */
mi set wide
mi register imputed age akps3_imp pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp ///
pospoormobility_imp posanxious_imp posfamilyanxiety_imp posdepressed_imp ///
posatpeace_imp possharefeelings_imp posinformation_imp pospracticalproblems_imp 
mi register regular gender2 livesalone3 diagnosis ethnicity5 imd_quint phase2 hosp_id 

/*set missing . to 99 for x vars in the mi model - so all cases are included in the MI*/
foreach var of varlist gender2 diagnosis phase2 {
replace `var' = 99 if `var'==.
}

/*Predictive Mean Matching (PMM) – regression based, predicts a value from estimated coefficients but then identifies an observed value that ///
is close to the estimated values and randomly imputes one of the observed values instead. Not useful if the for some reason you expect the values ///
of the missing to sit outside the range of the observed. Good for non-normal continuous vars – usually produce a distribution closer to the observed ///
than a regression would. */
//**CARRY OUT THE FULL IMPUTATION**//
/*NB - this is preliminary to save time - when i do this for real add(40) not 4!*/
mi impute chained (regress) age (pmm, knn(5)) akps3_imp pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp ///
pospoormobility_imp posanxious_imp posfamilyanxiety_imp posdepressed_imp ///
posatpeace_imp possharefeelings_imp posinformation_imp pospracticalproblems_imp ///
= i.gender2 i.diagnosis i.ethnicity5 i.livesalone3 ib5.imd_quint ib2.phase2 i.hosp_id, force add(40) rseed(88) savetrace(extrace, replace) burnin(100)

/*POST IMPUTATION CHECKS*/
//*check if imputed values match observed values*/
/*checking that the k-density plot is roughly normal*/
foreach var of varlist pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp ///
pospoormobility_imp posanxious_imp posfamilyanxiety_imp posdepressed_imp ///
posatpeace_imp possharefeelings_imp posinformation_imp pospracticalproblems_imp {
	mi xeq 0: sum `var'
	mi xeq 1/4: sum `var' if _miss`var'
	mi xeq 0: kdensity `var'; graph export chk`var'0.png, replace
	forval i=1/4 {
		mi xeq `i': kdensity `var' if _miss`var'; graph export chk`var'`i'.png, replace
	}
}

/*gen subscales*/
mi passive: egen physicali = rowtotal (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp) 
mi passive: egen emotionali = rowtotal (posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp)
mi passive: egen practicali = rowtotal (possharefeelings_imp posinformation_imp pospracticalproblems_imp)
mi passive: egen totaliposi = rowtotal (pospain_imp possob_imp posweakness_imp posnausea_imp posvomiting_imp ///
pospoorappetite_imp posconstipation_imp possoredrymouth_imp posdrowsiness_imp pospoormobility_imp ///
posanxious_imp posfamilyanxiety_imp posdepressed_imp posatpeace_imp ///
possharefeelings_imp posinformation_imp pospracticalproblems_imp)


save "$work\kch and pruh 2016 to 2019 deprivation eval referral level IMPUTED_40.dta",replace

clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level IMPUTED_40.dta"
/*return to missing for the sensitivity*/
foreach var of varlist gender2 diagnosis phase2 {
replace `var' = . if `var'==99
}


/*sensitivity analysis - run the main model on the MI data*/
mi estimate: regress physicali age i.gender2 ib5.imd_quint i.ethnicity5 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store physical
regsave using "$output\physicalregMI", ci pval replace
mi estimate: regress emotionali age i.gender2 ib5.imd_quint i.ethnicity5 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store emotional
regsave using "$output\emotionalregMI", ci pval replace
mi estimate: regress practicali age i.gender2 ib5.imd_quint i.ethnicity5 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store practical
regsave using "$output\practicalregMI", ci pval replace
coefplot physical, ///
		|| emotional, ///
		|| practical, ///
		||, nolabel drop(_cons) keep(*.imd_quint) xline(0) baselevels

			
clear
use "$output\physicalregMI"
keep var coef ci_lower ci_upper
rename coef physical
rename ci_lower lci_physical
rename ci_upper uci_physical
gen order=_n
save "$output\physicalregMI2", replace
clear
use "$output\emotionalregMI"
keep var coef ci_lower ci_upper
rename coef emotional
rename ci_lower lci_emotional
rename ci_upper uci_emotional
save "$output\emotionalregMI2", replace
clear
use "$output\practicalregMI"
keep var coef ci_lower ci_upper
rename coef practical
rename ci_lower lci_practical
rename ci_upper uci_practical
save "$output\practicalregMI2", replace 
clear
use "$output\physicalregMI2"
merge 1:1 var using "$output\emotionalregMI2"
drop _merge
merge 1:1 var using "$output\practicalregMI2"
drop _merge
order order
sort order
export excel using "$output\sensitivity.xls", firstrow(var) sheet("MI") sheetreplace		
/*******************************************************************************************************/


/******************************************************************************************************/
/*ANALYSIS*/
/*table 1 descriptives - covariates by imd*/

clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
table1, by(imd_quint) vars(age conts \ gender2 cat \ ethnicity5 cat \ livesalone3 cat \ diagnosis cat \ phase2 cat \ akps3_imp contn %4.1f \ hosp_id cat ) one mis cmis saving("$output\Table 1 by imd.xls", replace) 
table1, vars(age conts \ gender2 cat \ ethnicity5 cat \ livesalone3 cat \ diagnosis cat \ phase2 cat \ akps3_imp contn %4.1f \ hosp_id cat)  one mis cmis saving("$output\Table 1 by imd overall.xls", replace) 

misstable sum age akps3_imp, gen(miss)
tab imd_quint missage, mi row
tab imd_quint missakps3_imp, mi row

/*descriptives by site*/
table1, by(hosp_id) vars(age conts \ imd_quint cat \ physical_mdim contn %4.1f \ emotional_mdim contn %4.1f \ practical_mdim contn %4.1f )  one mis cmis saving("$output\descriptives by site.xls", replace) 

/*akps by phase to accompany figure 1 in appendix*/
replace phase2=99 if phase2==.
table1, by(phase2) vars(akps3_imp contn %4.1f \ akps3_imp conts \ missakps3_imp cat) one mis cmis saving("$output\akps by phase.xls", replace)
table1, vars(akps3_imp contn %4.1f \ akps3_imp conts \ missakps3_imp cat) one mis cmis saving("$output\akps overall.xls", replace)

/*figure 1 & 2 for appendix*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"

foreach var of varlist pospain_imp-pospracticalproblems_imp{
gen count_`var'=1 if `var'!=.
gen mso_`var'=1 if `var'>1 & `var'!=.
}

keep mso* count*
order mso* count*

collapse (count)count_pospain_imp-count_pospracticalproblems_imp (count)mso_pospain_imp-mso_pospracticalproblems_imp
save "$work\radar temp.dta", replace

clear
use "$work\radar temp.dta"
keep *pain*
gen item="pain"
rename count* count
gen prop=mso/count*100
save "$work\temp pain.dta", replace

clear
use "$work\radar temp.dta"
keep *sob*
gen item="shortness of breath"
rename count* count
gen prop=mso/count*100
save "$work\temp sob.dta", replace

clear
use "$work\radar temp.dta"
keep *weak*
gen item="weakness or lack of energy"
rename count* count
gen prop=mso/count*100
save "$work\temp weak.dta", replace

clear
use "$work\radar temp.dta"
keep *nausea*
gen item="nausea"
rename count* count
gen prop=mso/count*100
save "$work\temp nausea.dta", replace

clear
use "$work\radar temp.dta"
keep *vomit*
gen item="vomiting"
rename count* count
gen prop=mso/count*100
save "$work\temp vomit.dta", replace

clear
use "$work\radar temp.dta"
keep *appetite*
gen item="poor appetite"
rename count* count
gen prop=mso/count*100
save "$work\temp appetite.dta", replace

clear
use "$work\radar temp.dta"
keep *consti*
gen item="constipation"
rename count* count
gen prop=mso/count*100
save "$work\temp consti.dta", replace

clear
use "$work\radar temp.dta"
keep *mouth*
gen item="sore or dry mouth"
rename count* count
gen prop=mso/count*100
save "$work\temp mouth.dta", replace

clear
use "$work\radar temp.dta"
keep *drowsi*
gen item="drowsiness"
rename count* count
gen prop=mso/count*100
save "$work\temp drowsi.dta", replace

clear
use "$work\radar temp.dta"
keep *mobility*
gen item="poor mobility"
rename count* count
gen prop=mso/count*100
save "$work\temp mobility.dta", replace

clear
use "$work\radar temp.dta"
keep *anxious* 
gen item="patient anxiety"
rename count* count
gen prop=mso/count*100
save "$work\temp worried.dta", replace

clear
use "$work\radar temp.dta"
keep *family*
gen item="family anxiety"
rename count* count
gen prop=mso/count*100
save "$work\temp family.dta", replace

clear
use "$work\radar temp.dta"
keep *depres*
gen item="depression"
rename count* count
gen prop=mso/count*100
save "$work\temp depres.dta", replace

clear
use "$work\radar temp.dta"
keep *peace*
gen item="feeling at peace"
rename count* count
gen prop=mso/count*100
save "$work\temp peace.dta", replace

clear
use "$work\radar temp.dta"
keep *feelings*
gen item="sharing feelings"
rename count* count
gen prop=mso/count*100
save "$work\temp feelings.dta", replace

clear
use "$work\radar temp.dta"
keep *info*
gen item="information needs"
rename count* count
gen prop=mso/count*100
save "$work\temp info.dta", replace

clear
use "$work\radar temp.dta"
keep *practical*
gen item="practical matters"
rename count* count
gen prop=mso/count*100
save "$work\temp practical.dta", replace

/*append together*/
clear
use "$work\temp pain.dta"
append using "$work\temp sob.dta"
append using "$work\temp weak.dta"
append using "$work\temp nausea.dta"
append using "$work\temp vomit.dta"
append using "$work\temp appetite.dta"
append using "$work\temp consti.dta"
append using "$work\temp mouth.dta"
append using "$work\temp drowsi.dta"
append using "$work\temp mobility.dta"
append using "$work\temp worried.dta"
append using "$work\temp family.dta"
append using "$work\temp depres.dta"
append using "$work\temp peace.dta"
append using "$work\temp feelings.dta"
append using "$work\temp info.dta"
append using "$work\temp practical.dta"

/*gen vars for labels containing the n*/
tostring count, force replace
gen ipos=item + " " + "(n=" + count + ")"

encode ipos, gen(ipos2)
label list ipos2
gen ipos3=.
replace ipos3=1 if ipos2==11
replace ipos3=2 if ipos2==14
replace ipos3=3 if ipos2==16
replace ipos3=4 if ipos2==10
replace ipos3=5 if ipos2==15
replace ipos3=6 if ipos2==1
replace ipos3=7 if ipos2==2
replace ipos3=8 if ipos2==9
replace ipos3=9 if ipos2==4
replace ipos3=10 if ipos2==8
replace ipos3=11 if ipos2==17
replace ipos3=12 if ipos2==5
replace ipos3=13 if ipos2==3
replace ipos3=14 if ipos2==12
replace ipos3=15 if ipos2==6
replace ipos3=16 if ipos2==7
replace ipos3=17 if ipos2==13
labmask ipos3, values(ipos)
/*
radar ipos score, subtitle("mean ipos score at referral" " ") ///
lc(blue green) labsize(vsmall) lw(*1 *2) r(0 1 2 3 4) plotregion(color(none)) note("scale 0-4, centre is 0")*/
radar ipos prop, subtitle("% with moderate, severe or overwhelming on each IPOS item" " ") ///
lc(black) labsize(small) lw(*1 *2) r(0 10 20 30 40 50 60 70) note("") aspect(1) legend(off) graphregion(color(white))

/*create prev of ipos at each score for appendix*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
foreach var of varlist pospain_imp-pospracticalproblems_imp{
gen `var'_0=1 if `var'==0
gen `var'_1=1 if `var'==1
gen `var'_2=1 if `var'==2
gen `var'_3=1 if `var'==3
gen `var'_4=1 if `var'==4
gen `var'_d=1 if `var'!=.
}
collapse (sum) pospain_imp_0-pospracticalproblems_imp_d
order *_d*
gen id=1
reshape long pospain_imp_ possob_imp_ posweakness_imp_ posnausea_imp_ posvomiting_imp_ pospoorappetite_imp_ posconstipation_imp_ possoredrymouth_imp_ posdrowsiness_imp_ pospoormobility_imp_ posanxious_imp_ posfamilyanxiety_imp_ posdepressed_imp_ posatpeace_imp_ possharefeelings_imp_ posinformation_imp_ pospracticalproblems_imp_, i(id) j(count) 

foreach var of varlist pospain_imp_ - pospracticalproblems_imp_{
    gen `var'prop = `var'/`var'd*100
}
keep count *prop


/*distribution of akps by phase*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
bys phase2: gen total_n=_N
tostring total_n, force replace
decode phase2, gen(phase4)
gen n_phase= phase4 + " " + "(n=" + total_n + ")"
labmask phase2, values(n_phase)
set scheme s1color
tabplot akps3_imp , by(phase2, note("")) percent(phase2) yla(0(20)100) bfcolor(green) horizontal barw(10) yasis ytitle("AKPS")
sum akps3_imp , detail
bys phase2: sum akps3_imp , detail

/*******************************************************************************************************/

/*check relationships between the key variables - age, ipos, imd (not for paper)*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*graph the adjusted predicted means to visualise whether the relationships are linear*/
/*imd on age - older people are less deprived - linear*/
regress imd_quint age gender2
margins, at(age=(20(10)110))
marginsplot
/*ipos on age - as people age they have fewer physical and emotional problems but more practical problems*/
/*is this what we would expect?*/
regress physical_mdim age /*neg linear - fewer problems with increasing age*/
margins, at(age=(20(10)110))
marginsplot
regress emotional_mdim age /*neg linear - fewer problems with increasing age*/
margins, at(age=(20(10)110))
marginsplot
regress practical_mdim age /*pos linear - more problems with increasing age*/
margins, at(age=(20(10)110))
marginsplot
/*ipos on imd - non linear*/
regress physical_mdim i.imd_quint age gender2 
margins imd_quint
marginsplot
regress emotional_mdim i.imd_quint age gender2 
margins imd_quint
marginsplot
regress practical_mdim i.imd_quint age gender2 i.hosp_id
margins imd_quint
marginsplot
/*unerstanding the direction of the linear relationship*/
regress physical_mdim imd_dec age gender2
regress emotional_mdim imd_dec age gender2
regress practical_mdim imd_dec age gender2 i.ethnicity6 ib2.phase2 akps3_first hosp_id
/*confusingly - practical has a positive relationship (i.e. worse practical problems for people with less deprivation) until you adjust for hospid, then it becomes negaive in line with the other subscales*/
/*adding power terms to check for non linearity analytically - p38*/
regress physical imd_quint 
regress physical imd_quint c.imd_quint##c.imd_quint /*sig quadratic term and increase in r2 - suggest non linear*/
regress physical c.imd_quint##c.imd_quint##c.imd_quint /*non sig and trivial increase in r2 - suggest not a cubic term*/
/*lets test the linearity using factor variables*/
regress physical c.imd_quint i.imd_quint
testparm i.imd_quint /*sig results suggest significant contribution of the non linear terms*/
/*now to find out the nature of the non linear relationship*/
regress physical i.imd_quint
contrast p.imd_quint
/*describe the overlap between site and imd - potential multicolinearity issue*/
tab imd_quint hosp_id, col
/**************************************************************************************************/

/*table 3 - missing ipos subscale data complete case and post median imputation*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
sum physical3, detail
sum emotional3, detail
sum practical3, detail
misstable sum physical3 emotional3 practical3, gen (miss_)
tab miss_physical3 
tab miss_emotional3 
tab miss_practical3

sum physical_mdim, detail
sum emotional_mdim, detail
sum practical_mdim, detail
misstable sum  physical_mdim emotional_mdim practical_mdim, gen (miss_)
tab miss_physical_mdim 
tab miss_emotional_mdim 
tab miss_practical_mdim

/*for cases with missing IPOS data - how much clinician patient time did they have?*/
gen clinicaltimepatient_r10=1 if clinicaltimepatient_r<10
table1, by(miss_physical3) vars(clinicaltimepatient_r10 cat) saving("$output\clincialtime_ifmissingIPOS.xls", sheet("physical") sheetreplace)
table1, by(miss_emotional3) vars(clinicaltimepatient_r10 cat) saving("$output\clincialtime_ifmissingIPOS.xls", sheet("emotional") sheetreplace)
table1, by(miss_practical3) vars(clinicaltimepatient_r10 cat) saving("$output\clincialtime_ifmissingIPOS.xls", sheet("practical") sheetreplace)


/*Appendix*/
/*association with missing after median imputation*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
misstable sum physical_mdim emotional_mdim practical_mdim, gen(miss_)
logit miss_physical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id 
regsave using "$output\physicalmisslogit", ci pval replace
logit miss_emotional_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id
regsave using "$output\emotionalmisslogit", ci pval replace
logit miss_practical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id
regsave using "$output\practicalmisslogit", ci pval replace

clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*summarise % missing for covariates when subscale is !.*/
preserve 
misstable sum age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id, gen(miss_) 
keep if physical_mdim!=.
table1, vars(miss_age cat \ miss_gender2 cat \ miss_diagnosis cat \ miss_phase2 cat \ miss_akps3_imp cat \ ethnicity6 cat \ livesalone3 cat) one mis cmis saving("$output\missing_atsubscalecomplete.xls", sheet("physical") sheetreplace)
restore
preserve
misstable sum age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id, gen(miss_) 
keep if emotional_mdim!=.
table1, vars(miss_age cat \ miss_gender2 cat \ miss_diagnosis cat \ miss_phase2 cat \ miss_akps3_imp cat \ ethnicity6 cat \ livesalone3 cat) one mis cmis saving("$output\missing_atsubscalecomplete.xls", sheet("emotional") sheetreplace)
restore
preserve
misstable sum age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id, gen(miss_) 
keep if practical_mdim!=.
table1, vars(miss_age cat \ miss_gender2 cat \ miss_diagnosis cat \ miss_phase2 cat \ miss_akps3_imp cat \ ethnicity6 cat \ livesalone3 cat) one mis cmis saving("$output\missing_atsubscalecomplete.xls", sheet("practical") sheetreplace)
restore


/*MODELLING*/
/*********************************/
/*https://www3.nd.edu/~rwilliam/stats2/ - see for advice on comparing models
/*useful refresh on interpreting interactions: https://stats.idre.ucla.edu/stata/seminars/interactions-stata/#s4*/
*/

clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*make the sample consistent for the main modelling i.e. drop the missing cases for covariates*/
foreach var of varlist age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id  {
	drop if `var'==.
}
/*model fit - nested models*/
/*PHYSICAL*/
nestreg: regress physical_mdim (age i.gender2 ib5.imd_quint i.hosp_id), robust
nestreg: regress physical_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp), robust
nestreg: regress physical_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp) (i.ethnicity6), robust
nestreg: regress physical_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##c.age), robust
nestreg: regress physical_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##i.gender2), robust
/*save the imd coefs*/
regress physical_mdim age i.gender2 ib5.imd_quint i.hosp_id, robust
regsave using "$work\physicalMOD1", ci pval replace
regress physical_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
regsave using "$work\physicalMOD2", ci pval replace
regress physical_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id i.ethnicity6, robust
regsave using "$work\physicalMOD3", ci pval replace
regress physical_mdim i.gender2 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##c.age, robust
regsave using "$work\physicalMOD4", ci pval replace
regress physical_mdim age i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##i.gender2, robust
regsave using "$work\physicalMOD5", ci pval replace
forvalues i = 1/5 {
clear 
use "$work\physicalMOD`i'"
keep var coef ci_lower ci_upper 
rename coef mod`i'
rename ci_lower mod`i'_lci
rename ci_upper mod`i'_uci
rename var imd
keep if imd=="1.imd_quint" | imd=="2.imd_quint" | imd=="3.imd_quint" | imd=="4.imd_quint" | imd=="5b.imd_quint" ///
| imd=="1.imd_quint#c.age" | imd=="2.imd_quint#c.age" | imd=="3.imd_quint#c.age" | imd=="4.imd_quint#c.age" | imd=="5b.imd_quint#co.age" ///
| imd=="1.imd_quint#2.gender2" | imd=="2.imd_quint#2.gender2" | imd=="3.imd_quint#2.gender2" | imd=="4.imd_quint#2.gender2" | imd=="5b.imd_quint#2o.gender2"
save "$work\model`i'physical.dta", replace
}
clear
use "$work\model1physical.dta"
merge 1:1 imd using "$work\model2physical.dta"
drop _merge
merge 1:1 imd using "$work\model3physical.dta"
drop _merge
gen order=1
merge 1:1 imd using "$work\model4physical.dta"
drop _merge
replace order=2 if order==.
merge 1:1 imd using "$work\model5physical.dta"
drop _merge
replace order=3 if order==.
sort order imd
export excel using "$output\model_comparisons_coefs.xls", firstrow(var) sheet("physical") sheetreplace

/*EMOTIONAL*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*make the sample consistent for the main modelling i.e. drop the missing cases for covariates*/
foreach var of varlist age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id  {
	drop if `var'==.
}
nestreg: regress emotional_mdim (age i.gender2 ib5.imd_quint i.hosp_id), robust
nestreg: regress emotional_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp), robust
nestreg: regress emotional_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp) (i.ethnicity6), robust
nestreg: regress emotional_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##c.age), robust
nestreg: regress emotional_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##i.gender2), robust
/*save the imd coefs*/
regress emotional_mdim age i.gender2 ib5.imd_quint i.hosp_id, robust
regsave using "$work\emotionalMOD1", ci pval replace
regress emotional_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
regsave using "$work\emotionalMOD2", ci pval replace
regress emotional_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id i.ethnicity6, robust
regsave using "$work\emotionalMOD3", ci pval replace
regress emotional_mdim i.gender2 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##c.age, robust
regsave using "$work\emotionalMOD4", ci pval replace
regress emotional_mdim age i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##i.gender2, robust
regsave using "$work\emotionalMOD5", ci pval replace
forvalues i = 1/5 {
clear 
use "$work\emotionalMOD`i'"
keep var coef ci_lower ci_upper 
rename coef mod`i'
rename ci_lower mod`i'_lci
rename ci_upper mod`i'_uci
rename var imd
keep if imd=="1.imd_quint" | imd=="2.imd_quint" | imd=="3.imd_quint" | imd=="4.imd_quint" | imd=="5b.imd_quint" ///
| imd=="1.imd_quint#c.age" | imd=="2.imd_quint#c.age" | imd=="3.imd_quint#c.age" | imd=="4.imd_quint#c.age" | imd=="5b.imd_quint#co.age" ///
| imd=="1.imd_quint#2.gender2" | imd=="2.imd_quint#2.gender2" | imd=="3.imd_quint#2.gender2" | imd=="4.imd_quint#2.gender2" | imd=="5b.imd_quint#2o.gender2"
save "$work\model`i'emotional.dta", replace
}
clear
use "$work\model1emotional.dta"
merge 1:1 imd using "$work\model2emotional.dta"
drop _merge
merge 1:1 imd using "$work\model3emotional.dta"
drop _merge
gen order=1
merge 1:1 imd using "$work\model4emotional.dta"
drop _merge
replace order=2 if order==.
merge 1:1 imd using "$work\model5emotional.dta"
drop _merge
replace order=3 if order==.
sort order imd
export excel using "$output\model_comparisons_coefs.xls", firstrow(var) sheet("emotional") sheetreplace

/*PRACTICAL*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*make the sample consistent for the main modelling i.e. drop the missing cases for covariates*/
foreach var of varlist age gender2 imd_quint ethnicity6 livesalone3 diagnosis phase2 akps3_imp hosp_id  {
	drop if `var'==.
}
nestreg: regress practical_mdim (age i.gender2 ib5.imd_quint i.hosp_id), robust
nestreg: regress practical_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp), robust
nestreg: regress practical_mdim (age i.gender2 ib5.imd_quint i.hosp_id) (i.livesalone3 i.diagnosis ib2.phase2 akps3_imp) (i.ethnicity6), robust
nestreg: regress practical_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##c.age), robust
nestreg: regress practical_mdim (age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id) (ib5.imd_quint##i.gender2), robust
/*save the imd coefs*/
regress practical_mdim age i.gender2 ib5.imd_quint i.hosp_id, robust
regsave using "$work\practicalMOD1", ci pval replace
regress practical_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
regsave using "$work\practicalMOD2", ci pval replace
regress practical_mdim age i.gender2 ib5.imd_quint i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id i.ethnicity6, robust
regsave using "$work\practicalMOD3", ci pval replace
regress practical_mdim i.gender2 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##c.age, robust
regsave using "$work\practicalMOD4", ci pval replace
regress practical_mdim age i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id ib5.imd_quint##i.gender2, robust
regsave using "$work\practicalMOD5", ci pval replace
forvalues i = 1/5 {
clear 
use "$work\practicalMOD`i'"
keep var coef ci_lower ci_upper 
rename coef mod`i'
rename ci_lower mod`i'_lci
rename ci_upper mod`i'_uci
rename var imd
keep if imd=="1.imd_quint" | imd=="2.imd_quint" | imd=="3.imd_quint" | imd=="4.imd_quint" | imd=="5b.imd_quint" ///
| imd=="1.imd_quint#c.age" | imd=="2.imd_quint#c.age" | imd=="3.imd_quint#c.age" | imd=="4.imd_quint#c.age" | imd=="5b.imd_quint#co.age" ///
| imd=="1.imd_quint#2.gender2" | imd=="2.imd_quint#2.gender2" | imd=="3.imd_quint#2.gender2" | imd=="4.imd_quint#2.gender2" | imd=="5b.imd_quint#2o.gender2"
save "$work\model`i'practical.dta", replace
}
clear
use "$work\model1practical.dta"
merge 1:1 imd using "$work\model2practical.dta"
drop _merge
merge 1:1 imd using "$work\model3practical.dta"
drop _merge
gen order=1
merge 1:1 imd using "$work\model4practical.dta"
drop _merge
replace order=2 if order==.
merge 1:1 imd using "$work\model5practical.dta"
drop _merge
replace order=3 if order==.
sort order imd
export excel using "$output\model_comparisons_coefs.xls", firstrow(var) sheet("practical") sheetreplace
/*************************************/
/*SMD and e-values*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
/*create dummy vars*/
gen imdq1=0 
replace imdq1=1 if imd_quint==1 
gen imdq2=0 
replace imdq2=1 if imd_quint==2
gen imdq3=0 
replace imdq3=1 if imd_quint==3
gen imdq4=0 
replace imdq4=1 if imd_quint==4 
/*physical*/
regress physical_mdim age i.gender2 imdq1 imdq2 imdq3 imdq4 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust coeflegend
esizereg imdq1
esizereg imdq2
esizereg imdq3
esizereg imdq4
evalue_estat imdq1
evalue_estat imdq2 
evalue_estat imdq3 
evalue_estat imdq4 
regress emotional_mdim age i.gender2 imdq1 imdq2 imdq3 imdq4 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust coeflegend
esizereg imdq1
esizereg imdq2
esizereg imdq3
esizereg imdq4
evalue_estat imdq1
evalue_estat imdq2 
evalue_estat imdq3 
evalue_estat imdq4
regress practical_mdim age i.gender2 imdq1 imdq2 imdq3 imdq4 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust coeflegend
esizereg imdq1
esizereg imdq2
esizereg imdq3
esizereg imdq4
evalue_estat imdq1
evalue_estat imdq2 
evalue_estat imdq3 
evalue_estat imdq4

/********************************************/
/*main model*/
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
regress physical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store physical
regsave using "$output\physicalregMM", ci pval replace
regress emotional_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store emotional
regsave using "$output\emotionalregMM", ci pval replace
regress practical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store practical
regsave using "$output\practicalregMM", ci pval replace
coefplot physical, ///
		|| emotional, ///
		|| practical, ///
		||, nolabel drop(_cons) keep(*.imd_quint) xline(0) baselevels
		
/*margins to report the predicted mean scores for imd cats*/
regress physical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
margins imd_quint, saving("$output\marginsphysical", replace)	
regress emotional_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
margins imd_quint, saving("$output\marginsemotional", replace)	
regress practical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
margins imd_quint, saving("$output\marginspractical", replace)

/*moderation by age*/
/*to further understand the moderation by age, we plotted a linear effect of imd accross the age range*/
regress practical_mdim c.imd_quint##c.age i.gender2 i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2  c.akps3_imp i.hosp_id, robust
margins, dydx(imd_quint) at(age=(60(1)108)) saving("$output\marginsageimdmoderation", replace)
marginsplot, noci
marginsplot, yline(0) recast(line) recastci(rarea) xtitle("age") ytitle("linear effect of IMD on practical subscale" "") title("Linear effect (and 95% CI) of IMD on IPOS practical subscale, moderated by age" "" "" "", size(*0.8))

/*post estimation*/
/*see help regress postestimation*/
regress physical_mdim age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id 
rvfplot /*not a funnel but non-normal shape suggests heteroscadastic errors*/
predict rstudent, rstudent
predict pred, xb 
egen zpred = std(pred) 
twoway scatter rstudent zpred ||
lowess rstudent zpred
hettest
estat imtest, white
/*above suggest heteroscadastic errors*/
gen absresid = abs(rstudent)
regress absresid age i.gender2 i.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id 
/*sveral variables implicated - suggest we need robust SE*/
regress physical_mdim age i.gender2 i.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
vif /*no value greater than 10 suggests no colinearity*/

/*checking error distribution - nb this relates to model 1 i.e. not the robust se*/
kdensity rstudent /*looking for non-normality - here suggests some in the middle*/		
qnorm rstudent /*non normality in the tails*/
pnorm rstudent /*non normaility in the middle*/
/*2 plots above suggest both nonnormality in the middle and in the tails*/

/*SENSITIVITY*/
/*complete case*/		
clear
use "$work\kch and pruh 2016 to 2019 deprivation eval referral level.dta"
regress physical3 age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store physical
regsave using "$output\physicalregCC", ci pval replace
regress emotional3 age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store emotional
regsave using "$output\emotionalregCC", ci pval replace
regress practical3 age i.gender2 ib5.imd_quint i.ethnicity6 i.livesalone3 i.diagnosis ib2.phase2 akps3_imp i.hosp_id, robust
estimates store practical
regsave using "$output\practicalregCC", ci pval replace
coefplot physical, ///
		|| emotional, ///
		|| practical, ///
		||, nolabel drop(_cons) keep(*.imd_quint) xline(0) baselevels
clear
use "$output\physicalregCC"
keep var coef ci_lower ci_upper
rename coef physical
rename ci_lower lci_physical
rename ci_upper uci_physical
gen order=_n
save "$output\physicalregCC2", replace
clear
use "$output\emotionalregCC"
keep var coef ci_lower ci_upper
rename coef emotional
rename ci_lower lci_emotional
rename ci_upper uci_emotional
save "$output\emotionalregCC2", replace
clear
use "$output\practicalregCC"
keep var coef ci_lower ci_upper
rename coef practical
rename ci_lower lci_practical
rename ci_upper uci_practical
save "$output\practicalregCC2", replace 
clear
use "$output\physicalregCC2"
merge 1:1 var using "$output\emotionalregCC2"
drop _merge
merge 1:1 var using "$output\practicalregCC2"
drop _merge
order order
sort order
export excel using "$output\sensitivity.xls", firstrow(var) sheet("CC") sheetreplace
