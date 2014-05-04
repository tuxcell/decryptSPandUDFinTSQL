SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE sp_decryptsp  (@sp nvarchar(128)=NULL)
AS
declare @s varbinary(8000), @ptrval binary(16), @ptrval2 binary(16), @i int, @j int, @length int, @counter int, @counter2 int, @fill varbinary(8000), @Nfill nvarchar(4000)
,@temp nvarchar(4000), @temp1 varbinary(8000), @temp2 varbinary(8000), @temp3 varbinary(8000), @xor int, @SQL varchar(8000), 
@SQL2 varchar(8000), @SQL3 varchar(8000), @rest int

if NOT OBJECT_ID('tempdb..##DecryptedCode') IS NULL
	drop table ##DecryptedCode
create table ##DecryptedCode (dectxt ntext) 
--get SP encrypted code
create table #EncryptedCode (n image) 
insert #EncryptedCode values('')
SELECT @ptrval = TEXTPTR(n) FROM #EncryptedCode
create table #t(txt  varbinary(8000) )  
INSERT  #t  
SELECT c.ctext FROM sysobjects o INNER JOIN syscomments c ON c.id =o.id
WHERE o.type='p' and o.category=0 and encrypted=1 and name=@sp order by colid

--put together encrypted code
DECLARE _Cursor CURSOR FOR SELECT  * from #t
OPEN _Cursor
FETCH NEXT FROM _Cursor INTO @s
WHILE @@FETCH_STATUS=0
	BEGIN 
	set @i=(select DATALENGTH(n) from #EncryptedCode)
	UPDATETEXT #EncryptedCode.n @ptrval @i 0 @s
	FETCH NEXT FROM _Cursor INTO @s	
	END
CLOSE _Cursor
DEALLOCATE _Cursor
drop table #t
SET @length=(select DATALENGTH(n) from #EncryptedCode)

print 'create test code and code to alter the original code'
--create test code and code to alter the original code
--the global temporary table will be used first to make possible the execution of the dynamic SQL code
insert ##DecryptedCode values('ALTER PROCEDURE '+rtrim(@sp)+' with encryption AS ')
create table #TestCode (Ntest image) 
set @temp='CREATE PROCEDURE '+rtrim(@sp)+' with encryption AS '
insert #TestCode values(convert(varbinary(8000),@temp))
SELECT @ptrval = TEXTPTR(Ntest) FROM #TestCode
SELECT @ptrval2 = TEXTPTR(dectxt) FROM ##DecryptedCode
set @Nfill=replicate(N'-',4000)
set @fill=convert(varbinary(8000),@Nfill)
set @i=@length
set @counter=(select datalength(Ntest) from #TestCode)
set @counter2=(select datalength(dectxt) from ##DecryptedCode)/2

WHILE @i>0
	BEGIN
	IF @i>8000
		BEGIN
		UPDATETEXT #TestCode.Ntest @ptrval @counter 0 @fill
		UPDATETEXT ##DecryptedCode.dectxt @ptrval2 @counter2 0 @Nfill
		END
	ELSE
		BEGIN
		set @Nfill=replicate(N'-',@i/2)
		set @fill=convert(varbinary(8000),@Nfill)
		UPDATETEXT #TestCode.Ntest @ptrval @counter 0 @fill
		UPDATETEXT ##DecryptedCode.dectxt @ptrval2 @counter2 0 @Nfill
		END
	set @counter=@counter+8000
	set @counter2=@counter2+4000
	set @i=@i-8000
	END

print 'Alter original code'
--Alter original code
--get size of code
set @i=@length 
--create dynamic SQL code to perform alter
set @sql='declare @txtPtr varbinary(16) select @txtPtr = TEXTPTR(dectxt) from ##DecryptedCode DECLARE @buffer nvarchar(4000), '
set @sql2=' create table #t ( t text ) '
--Change the next exec with a print to examine the code without performing changes
set @sql3='exec ('
set @j=@i/8000
IF (@i % 8000)!=0
	set @j=@j+1
SET @rest=@i-(@i/8000)*8000
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
		set @sql2=@sql2+'insert into #t exec getREADTEXT ''dectxt'',''##DecryptedCode'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+',4000 set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar(4000),t) from #t) delete #t '
		END
	ELSE
		set @sql2=@sql2+'insert into #t exec getREADTEXT ''dectxt'',''##DecryptedCode'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+','+CONVERT(varchar(20),@rest/2)+' set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar('+CONVERT(varchar(20),@rest/2)+'),t) from #t) delete #t '
	set @j=@j-1
	set @counter=@counter+1
	END
set @sql3=@sql3+') '
set @sql=@sql+@sql2+@sql3+' drop table #t'
--execute dynamic SQL code
print @sql
exec(@sql)

print 'store altered encrypted code'
--store altered encrypted code
create table #EncryptedTestCode (NencTest image) 
insert #EncryptedTestCode values('')
--get SP encrypted code
SELECT @ptrval = TEXTPTR(NencTest) FROM #EncryptedTestCode
create table #t3(txt  varbinary(8000) )  
INSERT  #t3
SELECT c.ctext FROM sysobjects o INNER JOIN syscomments c ON c.id =o.id
WHERE o.type='p' and o.category=0 and encrypted=1 and name=@sp order by colid
--put together encrypted code
DECLARE _Cursor CURSOR FOR SELECT  * from #t3
OPEN _Cursor
FETCH NEXT FROM _Cursor INTO @s
WHILE @@FETCH_STATUS=0
	BEGIN 
	set @i=(select DATALENGTH(NencTest) from #EncryptedTestCode)
	UPDATETEXT #EncryptedTestCode.NencTest @ptrval @i 0 @s
	FETCH NEXT FROM _Cursor INTO @s	
	END
CLOSE _Cursor
DEALLOCATE _Cursor
drop table #t3

--clean temporary storage
delete ##DecryptedCode
insert ##DecryptedCode values('')

print 'perform XOR'
--perform XOR
set @i=@length
set @counter=0
create table #t2(txt  varbinary(8000) )  
while @i>0
	BEGIN
	if @i>8000
		BEGIN
		INSERT  #t2
		exec getREADTEXT 'n','#EncryptedCode', '', @counter, 8000
		set @temp1=(select txt from #t2)
		DELETE #t2
		INSERT  #t2
		exec getREADTEXT 'nTest','#TestCode', '', @counter, 8000
		set @temp2=(select txt from #t2)
		DELETE #t2
		INSERT  #t2
		exec getREADTEXT 'NencTest','#EncryptedTestCode', '', @counter, 8000
		set @temp3=(select txt from #t2)
		DELETE #t2
		set @temp=replicate(N' ',4000)
		set @j=1
		while @j<=8000
			BEGIN
			set @xor=ASCII(SUBSTRING(@temp1,@j,1)) ^ ASCII(SUBSTRING(@temp2,@j,1)) 
			^ ASCII(SUBSTRING(@temp3,@j,1))+
			(ASCII(SUBSTRING(@temp1,@j+1,1)) ^ ASCII(SUBSTRING(@temp2,@j+1,1)) 
			^ ASCII(SUBSTRING(@temp3,@j+1,1)))*256
			set @temp=STUFF(@temp,@j/2+1,1,nchar(@xor))
			set @j=@j+2
			END
		set @j=(select DATALENGTH(dectxt) from ##DecryptedCode)/2
		SELECT @ptrval = TEXTPTR(dectxt) FROM ##DecryptedCode
		--remove WITH ENCRYPTION
		IF @i=0
			BEGIN
			IF CHARINDEX('WITH ENCRYPTION',@temp )>0
				SET @temp=REPLACE(@temp,'WITH ENCRYPTION', '')
			ELSE
				IF (CHARINDEX('WITH',@temp )=1) AND (CHARINDEX('ENCRYPTION',@temp )=1)
					BEGIN
					SET @temp=REPLACE(@temp,'ENCRYPTION', '')
					SET @temp=REPLACE(@temp,'WITH', '')
					END
				ELSE
					BEGIN
					set @counter2=CHARINDEX('WITH',@temp)
					set @temp=STUFF(@temp,@counter2,4,'')
					set @counter2=CHARINDEX('ENCRYPTION',@temp)
					set @temp=STUFF(@temp,@counter2,10,'')
					END
			set @temp=RTRIM(@temp)
			END
		UPDATETEXT ##DecryptedCode.dectxt @ptrval @j 0 @temp
		END
	ELSE
		BEGIN
		INSERT  #t2
		exec getREADTEXT 'n','#EncryptedCode', '', @counter, @i
		set @temp1=(select txt from #t2)
		DELETE #t2
		INSERT  #t2
		exec getREADTEXT 'nTest','#TestCode', '', @counter, @i
		set @temp2=(select txt from #t2)
		DELETE #t2
		INSERT  #t2
		exec getREADTEXT 'NencTest','#EncryptedTestCode', '', @counter, @i
		set @temp3=(select txt from #t2)
		DELETE #t2
		set @temp=replicate(N' ',4000)
		set @j=1
		while @j<=@i
			BEGIN
			set @xor=ASCII(SUBSTRING(@temp1,@j,1)) ^ ASCII(SUBSTRING(@temp2,@j,1)) 
			^ ASCII(SUBSTRING(@temp3,@j,1))+
			(ASCII(SUBSTRING(@temp1,@j+1,1)) ^ ASCII(SUBSTRING(@temp2,@j+1,1)) 
			^ ASCII(SUBSTRING(@temp3,@j+1,1)))*256
			set @temp=STUFF(@temp,@j/2+1,1,nchar(@xor))
			set @j=@j+2
			END
		set @j=(select DATALENGTH(dectxt) from ##DecryptedCode)/2
		SELECT @ptrval = TEXTPTR(dectxt) FROM ##DecryptedCode
		--remove WITH ENCRYPTION
		IF CHARINDEX('WITH ENCRYPTION',@temp )>0
			SET @temp=REPLACE(@temp,'WITH ENCRYPTION', '')
		ELSE
			IF (CHARINDEX('WITH',@temp )=1) AND (CHARINDEX('ENCRYPTION',@temp )=1)
				BEGIN
				SET @temp=REPLACE(@temp,'ENCRYPTION', '')
				SET @temp=REPLACE(@temp,'WITH', '')
				END
			ELSE
				BEGIN
				set @counter2=CHARINDEX('WITH',@temp)
				set @temp=STUFF(@temp,@counter2,4,'')
				set @counter2=CHARINDEX('ENCRYPTION',@temp)
				set @temp=STUFF(@temp,@counter2,10,'')
				END
		set @temp=RTRIM(@temp)
		UPDATETEXT ##DecryptedCode.dectxt @ptrval @counter 0 @temp
		END
	set @counter=@counter+4000
	set @i=@i-8000
	END

drop table #t2

select dectxt from ##DecryptedCode

print 'replace code'
--replace code 
--drop original SP
EXECUTE ('DROP PROCEDURE '+ @sp)
--create dynamic SQL code to perform alter
set @i=(select DATALENGTH(dectxt) from ##DecryptedCode)
set @sql='declare @txtPtr varbinary(16) select @txtPtr = TEXTPTR(dectxt) from ##DecryptedCode DECLARE @buffer nvarchar(4000), '
set @sql2=' create table #t ( t text ) '
--Change the next exec with a print to examine the code without performing changes
set @sql3='exec ('
set @j=@i/8000
IF (@i % 8000)!=0
	set @j=@j+1
SET @rest=@i-(@i/8000)*8000
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
		set @sql2=@sql2+'insert into #t exec getREADTEXT ''dectxt'',''##DecryptedCode'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+',4000 set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar(4000),t) from #t) delete #t '
		END
	ELSE
		set @sql2=@sql2+'insert into #t exec getREADTEXT ''dectxt'',''##DecryptedCode'','''','+CONVERT(VARCHAR(20),(@counter-1)*4000)+','+CONVERT(VARCHAR(20),@rest/2)+' set @v'+CONVERT(NVARCHAR(9),@counter)+'=(select convert(nvarchar('+CONVERT(VARCHAR(20),@rest/2)+'),t) from #t) delete #t '
	set @j=@j-1
	set @counter=@counter+1
	END
set @sql3=@sql3+') '
set @sql=@sql+@sql2+@sql3+' drop table #t'
--execute dynamic SQL code
exec(@sql)


drop table #EncryptedCode
drop table #TestCode
drop table #EncryptedTestCode
drop table ##DecryptedCode
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

