/****** Script for variable - demand per patient per month  ******/
------# Main referrals extract for 2019
SELECT a.[Person_ID]
      ,a.[ServiceRequestId]
	  ,case
		when a.AgeServReferRecDate <25 then 'CYP'
		when a.AgeServReferRecDate between 25 AND 64 then 'Adult'
		when a.AgeServReferRecDate >64 then 'OlderAdult'
		else 'NoAgeRecorded' end as [AgeGroup] --for separate query can remove this case
      ,[ReferralRequestReceivedDate]
	  ,case when ServDischDate is NULL OR ServDischDate > '2020-03-31' then '2020-03-31' else ServDischDate end as EffectiveDischargeDate --adding pseudo end date if exceeds period of interest
	  ,b.ServTeamTypeRefToMH
  into #MHreferrals2019
  FROM [NHSE_MHSDS].[dbo].[MHS101Referral] a
  inner join [NHSE_MHSDS].[dbo].[MHS102ServiceTypeReferredTo] b
  on a.Person_ID = b.Person_ID
  and a.ServiceRequestId = b.ServiceRequestId

  where a.Der_Use_Submission_Flag = 'Y'
  and b.Der_Use_Submission_Flag = 'Y'
  and a.ReferralRequestReceivedDate between '2019-01-01' and '2019-12-31'
  and b.ReferRejectReason is NULL
  and b.ServTeamTypeRefToMH is not NULL --exclude unknown team/service type
  and b.ServTeamTypeRefToMH not in ('CAM','CHA','EO1','N/A','UNK','XXX') -- exclude some dodgy team types

  group by a.[Person_ID]
      ,a.[ServiceRequestId]
	  ,case
		when a.AgeServReferRecDate <25 then 'CYP'
		when a.AgeServReferRecDate between 25 AND 64 then 'Adult'
		when a.AgeServReferRecDate >64 then 'OlderAdult'
		else 'NoAgeRecorded' end --for separate query can remove this case
      ,[ReferralRequestReceivedDate]
	  ,case when ServDischDate is NULL OR ServDischDate > '2020-03-31' then '2020-03-31' else ServDischDate end
	  ,b.ServTeamTypeRefToMH

------# clinical contacts
Select Person_ID, ServiceRequestId, CareContactId, CareContDate, 1 as [Count]
into #MHcontacts2019
from [NHSE_MHSDS].[dbo].[MHS201CareContact]

where Der_Use_Submission_Flag = 'Y'
and CareContDate between '2019-01-01' and '2020-03-31'
and ([ClinContDurOfCareCont] is not NULL)-- only clinical contacts counted
and AttendOrDNACode in ('5','6') ----seen
and ConsType = '02' ----follow-up
and CareContSubj = '01' ----Patient is the subject
and consmediumused not in ('05','06','98') ----exclude non person-to-person

------# Contacts that occured only after referral dates
select a.Person_ID, a.ServiceRequestId, count(distinct CareContDate) as [Contacts_Sep] 
into #MHcontacts2019_2
from #MHcontacts2019 a
join  #MHreferrals2019 b
on a.Person_ID = b.Person_ID
and a.ServiceRequestId = b.ServiceRequestId
where a.CareContDate > b.ReferralRequestReceivedDate
and a.carecontdate <= b.EffectiveDischargeDate
group by a.Person_ID, a.ServiceRequestId
order by Person_ID, ServiceRequestId

------#count of contacts by referral with time elements added
Select a.Person_ID, a.servicerequestid, a.ServTeamTypeRefToMH, a.AgeGroup
, datediff(dd,ReferralRequestReceivedDate,EffectiveDischargeDate) as [DaysInSpell]
, datediff(dd,ReferralRequestReceivedDate,EffectiveDischargeDate)/365.25*12.0 as [MonthsInSpell]
, b.Contacts_Sep as [Contacts]
into #1
from #MHreferrals2019 a
join #MHcontacts2019_2 b
on a.Person_ID = b.Person_ID
and a.ServiceRequestId = b.ServiceRequestId

order by a.Person_ID, a.ServiceRequestId

------# Aggregate counts by Team Type
Select ServTeamTypeRefToMH, sum(MonthsInSpell) as [TotalMonths], sum(Contacts) as [TotalContacts]
into #2
from #1
group by ServTeamTypeRefToMH

Select ServTeamTypeRefToMH, TotalContacts/TotalMonths *1.0 as [Contacts_pppm]
from #2
order by ServTeamTypeRefToMH


--drop table #MHreferrals2019
--drop table #MHcontacts2019
--drop table #MHcontacts2019_2

--drop table #1
--drop table #2
--drop table #3

