WITH LoanTerms AS (
	SELECT
		[LoanId] = 1,
		[Amount] = 258300,
		[InterestRate] = 4.125,
		[Term] = 360,
		[AnnualPaymentCount] = 12

	UNION 

	SELECT
		[LoanId] = 2,
		[Amount] = 100000,
		[InterestRate] = 3.5,
		[Term] = 120,
		[AnnualPaymentCount] = 12
)

, PerPeriod AS (
	SELECT 
		[LoanId] = LoanId,
		[InterestRatePerPeriod] = (InterestRate / (100 * AnnualPaymentCount))
	FROM LoanTerms
)

, MonthlyPayments AS (
	SELECT 
	[LoanId] = L.LoanId,
	[InterestRatePerPeriod] = PP.InterestRatePerPeriod,
	[MonthlyPaymentAmount] = CAST(Amount /
	(( POWER(1 + PP.InterestRatePerPeriod, Term ) - 1) / 
	( PP.InterestRatePerPeriod * POWER( 1 + PP.InterestRatePerPeriod, Term ))) AS NUMERIC(14,2))
FROM LoanTerms L
	LEFT JOIN PerPeriod PP ON PP.LoanId = L.LoanId
)

, AmortizationSchedule (
	LoanId, 
	[Period],
	Term,
	InterestRatePerPeriod,
	StartingBalanceAmount, 
	MonthlyPaymentAmount,
	MonthlyInterestPaymentAmount,
	MonthlyPrincipalPaymentAmount,
	EndingBalanceAmount) 
	AS (
		SELECT
			[LoanId] = L.LoanId,
			[Period] = 1,
			[Term] = L.Term,
			[InterestRatePerPeriod] = InterestRatePerPeriod,
			[StartingBalanceAmount] = CAST(L.Amount AS NUMERIC(14,2)), 
			[MonthlyPaymentAmount] = MP.MonthlyPaymentAmount, 
			[MonthlyInterestPaymentAmount] = CAST(L.Amount * InterestRatePerPeriod AS NUMERIC(14,2)),
			[MonthlyPrincipalPaymentAmount] = CAST(MP.MonthlyPaymentAmount - (L.Amount * InterestRatePerPeriod) AS NUMERIC(14,2)),
			[EndingBalanceAmount] = CAST(L.Amount - (MP.MonthlyPaymentAmount - (L.Amount * InterestRatePerPeriod)) AS NUMERIC(14,2))
		FROM LoanTerms L
			LEFT JOIN MonthlyPayments MP ON MP.LoanId = L.LoanId

		UNION ALL

		SELECT
			[LoanId] = LoanId,
			[Period] = [Period] + 1,
			[Term] = Term,
			[InterestRatePerPeriod] = InterestRatePerPeriod,
			[StartingBalanceAmount] = CAST(EndingBalanceAmount AS NUMERIC(14,2)), 
			[MonthlyPaymentAmount] = MonthlyPaymentAmount, 
			[MonthlyInterestPaymentAmount] = CAST(EndingBalanceAmount * InterestRatePerPeriod AS NUMERIC(14,2)),
			[MonthlyPrincipalPaymentAmount] = CAST(MonthlyPaymentAmount - (EndingBalanceAmount * InterestRatePerPeriod)AS NUMERIC(14,2)),
			[EndingBalanceAmount] = CAST(EndingBalanceAmount - (MonthlyPaymentAmount - (EndingBalanceAmount * InterestRatePerPeriod)) AS NUMERIC(14,2))
		FROM AmortizationSchedule
		WHERE [Period] < Term		
)

SELECT 
	[Loan Id]                              = LoanId,
	[Period]                               = Period,  
	[Starting Balance Amount ($)]          = FORMAT(StartingBalanceAmount, '#,000.00'),
	[Monthly Payment Amount ($)]           = FORMAT(MonthlyPaymentAmount, '#,000.00'),
	[Monthly Interest Payment Amount ($)]  = FORMAT(MonthlyInterestPaymentAmount, '#,000.00'),
	[Monthly Principal Payment Amount ($)] = FORMAT(MonthlyPrincipalPaymentAmount, '#,000.00'),
	[Ending Balance Amount ($)]            = FORMAT(EndingBalanceAmount, '#,000.00')
FROM AmortizationSchedule  
ORDER BY LoanId, [Period]
OPTION (MAXRECURSION 360)