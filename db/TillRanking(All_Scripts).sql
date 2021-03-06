USE [mobileBanking]
GO
/****** Object:  UserDefinedFunction [dbo].[FullMonthsSeparation]    Script Date: 04/26/2015 22:01:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[FullMonthsSeparation] 
(
    @DateA DATETIME,
    @DateB DATETIME
)
RETURNS INT
AS
BEGIN
    DECLARE @Result INT

    DECLARE @DateX DATETIME
    DECLARE @DateY DATETIME

    IF(@DateA < @DateB)
    BEGIN
    	SET @DateX = @DateA
    	SET @DateY = @DateB
    END
    ELSE
    BEGIN
    	SET @DateX = @DateB
    	SET @DateY = @DateA
    END

    SET @Result = (
    				SELECT 
    				CASE 
    					WHEN DATEPART(DAY, @DateX) > DATEPART(DAY, @DateY)
    					THEN DATEDIFF(MONTH, @DateX, @DateY) - 1
    					ELSE DATEDIFF(MONTH, @DateX, @DateY)
    				END
    				)

    RETURN @Result
END
GO
/****** Object:  Table [dbo].[TillRanges]    Script Date: 04/26/2015 22:01:26 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TillRanges](
	[min_value] [numeric](11, 0) NOT NULL,
	[max_value] [numeric](18, 0) NULL,
	[grade] [nchar](10) NOT NULL,
	[description] [varchar](50) NULL,
	[id] [int] NULL
) ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
INSERT [dbo].[TillRanges] ([min_value], [max_value], [grade], [description], [id]) VALUES (CAST(50001 AS Numeric(11, 0)), CAST(100000 AS Numeric(18, 0)), N'D         ', N'Below Average', 4)
INSERT [dbo].[TillRanges] ([min_value], [max_value], [grade], [description], [id]) VALUES (CAST(100001 AS Numeric(11, 0)), CAST(500000 AS Numeric(18, 0)), N'C         ', N'Average Perfomer', 3)
INSERT [dbo].[TillRanges] ([min_value], [max_value], [grade], [description], [id]) VALUES (CAST(500001 AS Numeric(11, 0)), CAST(1000000 AS Numeric(18, 0)), N'B         ', N'Above Average', 2)
INSERT [dbo].[TillRanges] ([min_value], [max_value], [grade], [description], [id]) VALUES (CAST(1000001 AS Numeric(11, 0)), NULL, N'A         ', N'High Perfomer', 1)
INSERT [dbo].[TillRanges] ([min_value], [max_value], [grade], [description], [id]) VALUES (CAST(0 AS Numeric(11, 0)), CAST(50000 AS Numeric(18, 0)), N'E         ', N'Poor Perfomer', 5)
/****** Object:  UserDefinedFunction [dbo].[fn_GetTillAverage]    Script Date: 04/26/2015 22:01:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*Function GetTillAverage

		Author: Tom Kimani
		
		Date: April 23

		Purpose: Returns grade of a merchant given a business Number

		Arguments: 
			1. @businessNumber Varchar for Merchant
			2. @startDate VarChar in the format '2014-10-01'
			3. @endDate VarChar in the format '2014-10-01'
			
		Return type: Numeric(12,2)
	*/
	CREATE Function [dbo].[fn_GetTillAverage](
		@businessNo varchar(10),
		@startDate varchar(50),
		@endDate varchar(50)
	 )
	returns numeric(11,0) AS
	
	BEGIN
			DECLARE @timePeriod numeric(2,0)
			DECLARE @totalAmount numeric(35,0)
			DECLARE @averageAmt numeric(11,0)

			--/*Get totalAmount startDate and endDate and businessNo*/
			set @timePeriod= dbo.FullMonthsSeparation(@startDate,@endDate)

			select  @totalAmount = SUM(mpesa_amt) from LipaNaMpesaIPN where 
			tstamp>=@startDate and tstamp<=@endDate
			and business_number=@businessNo
					
			/*Time Period*/
			if @timePeriod<1
				set @timePeriod = 1

			set @averageAmt = @totalAmount / @timePeriod
			if @averageAmt IS NULL
				set @averageAmt=0	
		return @averageAmt
	END
GO
/****** Object:  UserDefinedFunction [dbo].[fn_GetTillRank]    Script Date: 04/26/2015 22:01:29 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*Function GetTillRank

		Author: Tom Kimani
		
		Date: April 23

		Purpose: Returns grade of a merchant given a business Number

		Arguments: 
			1. @businessNumber Varchar for Merchant
			2. @startDate VarChar in the format '2014-10-01'
			3. @endDate VarChar in the format '2014-10-01'
			
		Return type: Numeric(12,2)
	*/
	CREATE Function [dbo].[fn_GetTillRank]
		(@businessNo Varchar(10), @startDate varchar(50),@endDate varchar(50))
		Returns varchar(10)
	As
	Begin
		DECLARE @totalAmount numeric(35,0)
		DECLARE @min_value numeric(35,0)
		DECLARE @max_value numeric(35,0)
		DECLARE @grade varchar(10)
		DECLARE @timePeriod numeric(2,0)
		DECLARE @averageAmt numeric(11,0)
		DECLARE @tblCount int
		DECLARE @counter int
		DECLARE @startpoint int
		DECLARE @description varchar(50)
		DECLARE @maximum_amt numeric(11,0)
		DECLARE @returnVal varchar(10)
		

		select @averageAmt = dbo.fn_GetTillAverage(@businessNo,@startDate,@endDate)
		
		--print 'Average Amount:'+ cast(@averageAmt as varchar)
		--print 'Time Period:'+ cast(@timePeriod as varchar)

		SET @counter = 1

		SELECT TOP 1 @startpoint=id from TillRanges order by id ASC
		SELECT @maximum_amt = min_value from TillRanges where id=1

		select @tblCount=COUNT(*) from TillRanges

		while(@counter <= @tblCount)
			BEGIN
				select @min_value = min_value,@max_value=max_value,@grade=grade,@description=description from TillRanges
				where id=@startpoint
				
				--print 'Max Values>>'+CAST(@startpoint as varchar)+'::'+cast(@max_value as varchar)
				
				if @averageAmt >= @maximum_amt
					BEGIN
						--print 'Grade::' + @grade + 'Description:'+ @description
						select @returnVal=@grade
						break
					END	
				ELSE IF @averageAmt >= @min_value AND @averageAmt <= @max_value
					  BEGIN
						  --print 'id:'+CAST(@startpoint as varchar)+'>>'+CAST(@min_value AS varchar) +'-'
						  --+ cast(@max_value as varchar)
						  --print 'Grade::' + @grade + '::'+ @description
						  select @returnVal=@grade
						 break
					 END
				ELSE
					select @returnVal=@grade
				
				/****************************/
				SELECT @counter=@counter+1
				SELECT @startpoint=@startpoint+1
			END
		return @returnVal
	END
GO
/****** Object:  View [dbo].[TillGrades]    Script Date: 04/26/2015 22:01:30 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[TillGrades] AS select business_number, dbo.fn_getTillAverage(business_number,'2015-01-01','2015-04-26') as tillAverage, dbo.fn_GetTillRank(business_number,'2015-01-01','2015-04-26') as grade from TillModel
GO
