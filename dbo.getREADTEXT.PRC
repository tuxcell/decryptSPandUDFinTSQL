SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE getREADTEXT @column nvarchar(128), @table nvarchar(128),@where nvarchar(4000),@position int,@length int
--given a column, table and filter clause plus a position to start reading the text and length to be read, the selected portion of the text will be returned
AS
declare @sql nvarchar(4000)
set @sql='declare @txtPtr varbinary(16)
select @txtPtr = TEXTPTR('+@column+') from '+@table+' '+@where+
' READTEXT '+@table+'.'+@column+' @txtPtr '+str(@position)+' '+str(@length)+''
exec(@sql)
GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

