SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE  PROCEDURE sp_encryptsp (@sp nvarchar(128)=NULL)
--This SP will encrypt other Sp's, even if they are over 8 kb
AS
SET NOCOUNT ON
declare @s nvarchar(4000), @ptrval binary(16), @i int, @j int, @tmp nvarchar(4000), @tmp2 nvarchar(4000), @counter int, @position int
declare @SQL varchar(8000), @SQL2 varchar(8000), @SQL3 varchar(8000), @rest varchar(20)
--check for errors
IF (@sp is NULL)
	BEGIN
	PRINT 'sp_encryptsp encrypts a stored procedure that can be longer than 8kb'
	PRINT 'Usage:'
	PRINT 'EXEC sp_encryptsp StoredProcedureName'
	PRINT ''
	PRINT 'For example: EXEC sp_encryptsp ''sp_name'''
	RETURN
	END
IF EXISTS(SELECT o.name FROM sysobjects o INNER JOIN syscomments c ON c.id = o.id
WHERE o.type='p' and o.category=0 and o.name=@sp and encrypted=1) 
	BEGIN
	PRINT 'SP '''+@sp+''' is already encrypted!'
	RETURN
	END
IF NOT EXISTS(SELECT o.name FROM sysobjects o INNER JOIN syscomments c ON c.id = o.id
WHERE o.type='p' and o.category=0 and o.name=@sp and encrypted=0 ) 
	BEGIN
	PRINT 'SP '''+@sp+''' not found!'
	RETURN
	END

--get SP code
create table ##NtextTempTable (n ntext) 
insert ##NtextTempTable values('')
SELECT @ptrval = TEXTPTR(n) FROM ##NtextTempTable
create table #t(txt  nvarchar(4000) )  
INSERT  #t  
exec sp_helptext @sp 
DECLARE _Cursor CURSOR FOR SELECT  * from #t
OPEN _Cursor
FETCH NEXT FROM _Cursor INTO @s
WHILE @@FETCH_STATUS=0
	BEGIN 
	set @i=(select DATALENGTH(n) from ##NtextTempTable)/2
	UPDATETEXT ##NtextTempTable.n @ptrval @i 0 @s
	FETCH NEXT FROM _Cursor INTO @s	
	END
CLOSE _Cursor
DEALLOCATE _Cursor
delete #t
drop table #t

--look for create statement
set @tmp='%create procedure%'
SET @i= (select PATINDEX(@tmp, n) FROM ##NtextTempTable)-1
IF @i=-1 --Couldn't find 'create procedure'
	BEGIN
	PRINT 'Couldn''t find ''create procedure'' statement on '+@sp
	GOTO lblEND
	END
set @tmp2='alter procedure'
set @j=len(@tmp)-2
UPDATETEXT ##NtextTempTable.n @ptrval @i @j @tmp2

--look for as statement
SET @i= (select PATINDEX('%[ 	
]as[ 	
]%', n) FROM ##NtextTempTable)

IF @i=-1 --Couldn't find 'as'
	BEGIN
	PRINT 'Couldn''t locate ''as'' statement on '+@sp
	GOTO lblEND
	END

--change code
UPDATETEXT ##NtextTempTable.n @ptrval @i 0 ' with encryption '

--get size of code
set @i=(select DATALENGTH(n) from ##NtextTempTable)/2

--create dynamic SQL code to perform alter
set @sql='declare @txtPtr varbinary(16)
select @txtPtr = TEXTPTR(n) from ##NtextTempTable
DECLARE @buffer nvarchar(4000), '
set @sql2='create table #t ( t text ) 
'
--Change the next exec with a print to examine the code without performing changes
set @sql3='exec ('
set @j=@i/4000
IF (@i % 4000)!=0
	BEGIN
	set @j=@j+1
	SET @rest=CONVERT(varchar(20),@i-(@i/4000)*4000)
	END
ELSE
	SET @rest='4000'

set @counter=1
--loop to create dynamic SQL code
WHILE @j>0
	BEGIN
	set @sql=@sql+'@v'+CONVERT(NVARCHAR(9),@counter)+' nvarchar(4000) '
	set @sql3=@sql3+'@v'+CONVERT(NVARCHAR(9),@counter)
	IF @j>1 
		BEGIN
		set @sql3=@sql3+'+'
		set @sql=@sql+', '
		set @sql2=@sql2+'insert into #t 
	exec getREADTEXT ''n'',''##NtextTempTable'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+',4000
set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar(4000),t) from #t)
delete #t
'
		END
	ELSE
		set @sql2=@sql2+'insert into #t 
	exec getREADTEXT ''n'',''##NtextTempTable'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+','+@rest+'
set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar('+@rest+'),t) from #t)
delete #t
'
	set @j=@j-1
	set @counter=@counter+1
	END
set @sql3=@sql3+')'
set @sql=@sql+@sql2+@sql3+' drop table #t'
--execute dynamic SQL code
exec(@sql)
lblEND:
drop table ##NtextTempTable
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

