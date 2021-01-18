/****** Script for variable - % referrals taken into service  ******/

------# Use these 2 rows if want a specific provider cut. If CCG registered or LA resident cut required then would need to join ref and patient ID to MPI table to pull relevant field
--Declare @Trust varchar(3)
--set @Trust = 'RXA'

SELECT [MHS101UniqID]
      ,[Person_ID]
      ,[OrgIDProv]
      ,[UniqSubmissionID]
      ,[UniqMonthID]
      ,[RecordNumber]
      ,[RowNumber]
      ,[ServiceRequestId]
      ,[OrgIDComm]
      ,[ReferralRequestReceivedDate]
      ,[SourceOfReferralMH]
      ,[PrimReasonReferralMH]
      ,[ServDischDate]
      ,[UniqServReqID]
      ,[AgeServReferRecDate]
      ,[RecordStartDate]
      ,[RecordEndDate]
      ,[InactTimeRef]
      ,[NHSEUniqSubmissionID]
      ,[Der_Use_Submission_Flag]
	  
into #stage1 --use view or fixed table if prefer
  FROM [NHSE_MHSDS].[dbo].[MHS101Referral] 

  where ReferralRequestReceivedDate between '2018-01-01' AND '2018-12-31'
  and ((RecordStartDate is not NULL AND RecordEndDate is NULL) -- open referrals
		OR ServDischDate is not NULL) --discharged referrals
  --and left(ref.OrgIDProv,3) = @Trust

select a.*
,serv.ServTeamTypeRefToMH
,serv.ReferClosReason
,serv.ReferClosureDate
,serv.ReferRejectReason
,serv.ReferRejectionDate

into #stage2
from #stage1 a

  left outer join [NHSE_MHSDS].[dbo].[MHS102ServiceTypeReferredTo] serv
  on a.ServiceRequestId = serv.ServiceRequestId
  and a.RecordNumber = serv.RecordNumber

  where ServTeamTypeRefToMH is not NULL
	and ServTeamTypeRefToMH not in ('CAM','CHA','EO1','N/A','UNK','XXX') -- some dodgy team types

Select ServTeamTypeRefToMH
, count(*) as [All Refs]
, sum(case when ReferClosReason in ('05','08','09') then 1 else 0 end) as [patient declined]
, sum(case when ReferRejectionDate is not NULL then 1 else 0 end) as [referral rejected]

into #final
from #stage2 a
inner join (select ServiceRequestId, max(RowNumber) as [RowNumber]
			from #stage2
			group by ServiceRequestId) b
	on a.ServiceRequestId = b.ServiceRequestId
	and a.RowNumber = b.RowNumber --only most recent row per referral ID
where ReferRejectReason != '01' OR ReferRejectReason is NULL
group by ServTeamTypeRefToMH 
order by ServTeamTypeRefToMH

Select *
, 1-(cast(([patient declined]+[referral rejected]) as float)/[All refs]) as [treat_pcnt]
from #final

order by ServTeamTypeRefToMH

--drop table #stage1
--drop table #stage2
--drop table #final
