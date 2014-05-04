SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS OFF 
GO

CREATE PROCEDURE DECRYPT2K (@objName varchar(50), @type char(1) )
--INPUT: object name (stored procedure, 
--     view or trigger), object type ('S'-store
--     d procedure, 'V'view or 'T'-trigger)
--Original idea: shoeboy <shoeboy@ade
--     quacy.org>
--Copyright © 1999-2002 SecurityFocus 
--adapted by Joseph Gama
--Planet Source Code, my employer and my
--     self are not responsible for the use of 
--     this code
--This code is provided as is and for ed
--     ucational purposes only
--Please test it and share your results
 AS
DECLARE @a nvarchar(4000), @b nvarchar(4000), @c nvarchar(4000), @d nvarchar(4000), @i int, @t bigint, @tablename varchar(255), @trigtype varchar(6)
SET @type=UPPER(@type)
IF @type='T'
	BEGIN
	SET @tablename=(SELECT sysobjects_1.name
	FROM dbo.sysobjects INNER JOIN
	 dbo.sysobjects sysobjects_1 ON dbo.sysobjects.parent_obj = sysobjects_1.id
	WHERE (dbo.sysobjects.type = 'TR') AND (dbo.sysobjects.name = @objName))
	SET @trigtype=(SELECT CASE WHEN dbo.sysobjects.deltrig > 0 THEN 'DELETE' 
					WHEN dbo.sysobjects.instrig > 0 THEN 'INSERT' 
					WHEN dbo.sysobjects.updtrig > 0 THEN 'UPDATE' END
			FROM dbo.sysobjects INNER JOIN
			 dbo.sysobjects sysobjects_1 ON dbo.sysobjects.parent_obj = sysobjects_1.id
			WHERE (dbo.sysobjects.type = 'TR') AND (dbo.sysobjects.name = @objName))
	END
--get encrypted data
SET @a=(SELECT ctext FROM syscomments WHERE id = object_id(@objName))
SET @b=case @type 
		WHEN 'S' THEN 'ALTER PROCEDURE '+ @objName +' WITH ENCRYPTION AS '+REPLICATE('-', 4000-62)
		WHEN 'V' THEN 'ALTER VIEW '+ @objName +' WITH ENCRYPTION AS SELECT dbo.dtproperties.* FROM dbo.dtproperties'+REPLICATE('-', 4000-150)
		WHEN 'T' THEN 'ALTER TRIGGER '+@objName+' ON '+ @tablename+' WITH ENCRYPTION FOR '+@trigtype+' AS PRINT ''a'''+REPLICATE('-', 4000-150)
		END
EXECUTE (@b)
--get encrypted bogus SP
SET @c=(SELECT ctext FROM syscomments WHERE id = object_id(@objName))
SET @b=case @type 
	WHEN 'S' THEN 'CREATE PROCEDURE '+ @objName +' WITH ENCRYPTION AS '+REPLICATE('-', 4000-62)
	WHEN 'V' THEN 'CREATE VIEW '+ @objName +' WITH ENCRYPTION AS SELECT dbo.dtproperties.* FROM dbo.dtproperties'+REPLICATE('-', 4000-150)
	WHEN 'T' THEN 'CREATE TRIGGER '+@objName+' ON '+ @tablename+' WITH ENCRYPTION FOR '+@trigtype+' AS PRINT ''a'''+REPLICATE('-', 4000-150)
	END
--start counter
SET @i=1
--fill temporary variable
SET @d = replicate(N'A', (datalength(@a) / 2))
--loop
WHILE @i<=datalength(@a)/2
	BEGIN
--xor original+bogus+bogus encrypted
SET @d = stuff(@d, @i, 1,
 NCHAR(UNICODE(substring(@a, @i, 1)) ^
 (UNICODE(substring(@b, @i, 1)) ^
 UNICODE(substring(@c, @i, 1)))))
	SET @i=@i+1
	END
--drop original SP
IF @type='S'
	EXECUTE ('drop PROCEDURE '+ @objName)
ELSE
	IF @type='V'
		EXECUTE ('drop VIEW '+ @objName)
	ELSE
		IF @type='T'
			EXECUTE ('drop TRIGGER '+ @objName)
--remove encryption
--try to preserve case
SET @d=REPLACE((@d),'WITH ENCRYPTION', '')
SET @d=REPLACE((@d),'With Encryption', '')
SET @d=REPLACE((@d),'with encryption', '')
IF CHARINDEX('WITH ENCRYPTION',UPPER(@d) )>0
	SET @d=REPLACE(UPPER(@d),'WITH ENCRYPTION', '')
--replace SP
execute( @d)

GO
SET QUOTED_IDENTIFIER OFF 
GO
SET ANSI_NULLS ON 
GO

