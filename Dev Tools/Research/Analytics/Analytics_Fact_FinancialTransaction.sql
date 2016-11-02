CREATE UNIQUE CLUSTERED INDEX IDX_V1   
    ON vAnalytics_Fact_FinancialTransaction (OrderDate, ProductID);  
GO 

create view vAnalytics_Fact_FinancialTransaction
with schemabinding as
select
	concat(ft.Id, '_', ftd.Id) [TransactionKey],
	convert(char(8), ft.TransactionDateTime, 112) [TransactionDateKey],
	-- ?? ft.TransactionDateTime,
	ft.TransactionCode [TransactionCode],
	ft.Summary [TransactionSummary],
	ft.TransactionTypeValueId [TransactionTypeValueId],
	ft.SourceTypeValueId [SourceTypeValueId],
	case ft.ScheduledTransactionId when null then 'Scheduled' else 'Non-Scheduled' end [ScheduleType],
	-- todo [AuthorizedPersonKey]
	paAuthorizedPerson.PersonId [AuthorizedCurrentPersonId],
	-- todo ProcessedPersonKey
	paProcessedByPerson.PersonId [ProcessedCurrentPersonId],
	ft.ProcessedDateTime,
	-- todo [GivingUnitKey]
	p.GivingGroupId [GivingGroupId],
	-- todo [BatchKey]
	ft.BatchId,
	ft.FinancialGatewayId,  
	et.FriendlyName [EntityTypeName],
	ftd.EntityTypeId,
	ftd.EntityId,
	ft.Id [TransactionId],
	ftd.Id [TransactionDetailId],
	ftd.AccountId [AccountKey],
	fpd.CurrencyTypeValueId,
	fpd.CreditCardTypeValueId,
	-- TODO DaysSinceLastTransactionOfType, NumberOfDays (NULLable), Last Time This Giving Unit did a "Contribution/Event" TransactionType that is the same as this TransactionType
	-- TODO IsFirstTransactionOfType
	-- TODO AuthorizedFamilyKey
	-- TODO AuthorizedFamilyId
	1 [Count],
	ftd.Amount [Amount],
	ftd.ModifiedDateTime
	from FinancialTransaction ft
join FinancialTransactionDetail ftd on ftd.TransactionId = ft.Id
join PersonAlias paAuthorizedPerson on ft.AuthorizedPersonAliasId = paAuthorizedPerson.Id
join Person p on p.Id = paAuthorizedPerson.PersonId
left join PersonAlias paProcessedByPerson on ft.ProcessedByPersonAliasId = paProcessedByPerson.Id
left join EntityType et on ftd.EntityTypeId = et.Id
left join FinancialPaymentDetail fpd on ft.FinancialPaymentDetailId = fpd.Id

