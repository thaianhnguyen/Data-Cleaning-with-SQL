-- define used database
USE [Bombing Attacks];
GO;

select * from PakistanSuicideAttacks ;

-- FORMAT DATE COLUMNS
Select Date, 
	   CAST(REPLACE(RIGHT(Date, LEN(Date)-CHARINDEX('-',Date)),'-', ' ') AS DATE)
from PakistanSuicideAttacks;

UPDATE PakistanSuicideAttacks
SET Date = CAST(REPLACE(RIGHT(Date, LEN(Date)-CHARINDEX('-',Date)),'-', ' ') AS DATE);
---- Set data type of column into Date type
ALTER TABLE PakistanSuicideAttacks
ALTER COLUMN  Date Date;

-------------------

-- NULL VALUES
select Date, 
	   format(date, 'MM-dd') as monthday, 
	   DATENAME(dw,date),DATEPART(weekday,date) as DoW, 
	   Blast_Day_Type,
	   Case when format(date, 'MM-dd') in (select distinct format(date, 'MM-dd')
										   from PakistanSuicideAttacks
										   where Blast_Day_Type = 'Holiday')
			then 'Holiday'
			when DATEPART(weekday,date) % 7 in (1,0)
			then 'Weekend'
			else 'Working Day' end as modified_day_type
from PakistanSuicideAttacks
where Blast_Day_Type is null
order by monthday;

UPDATE PakistanSuicideAttacks
SET Blast_Day_Type = 
	Case when format(date, 'MM-dd') in (select distinct format(date, 'MM-dd')
										from PakistanSuicideAttacks
										where Blast_Day_Type = 'Holiday')
	     then 'Holiday' 
		 when DATEPART(weekday,date) % 7 in (1,0)
		 then 'Weekend'
		 else 'Working Day' end 
where Blast_Day_Type is null;
---- there is limitation, however. There might be other holidays that are not specified in table 

-- INCONSISTENT DATA ENTRY
-- City Column

----  manually check distinct values of city 
select distinct city
from PakistanSuicideAttacks;
-- inconsistent cases; "D.I Khan"; too specific info like "Ghallanai, Mohmand Agency","Tangi, Charsadda District" ; mispronounced "Kuram" and "Kurram"

---- double check for any other mispronounced city names 
select distinct t1.city
from PakistanSuicideAttacks t1
inner join PakistanSuicideAttacks t2
on SOUNDEX(replace(t1.city,' ','')) = SOUNDEX(replace(t2.city,' ',''))
and t1.city <> t2.city;

---- re-format each words in city name with capitalized initials
------ Create function InitCap
CREATE FUNCTION [dbo].[InitCap] ( @InputString varchar(4000) ) 
RETURNS VARCHAR(4000)
AS
BEGIN

DECLARE @Index          INT
DECLARE @Char           CHAR(1)
DECLARE @PrevChar       CHAR(1)
DECLARE @OutputString   VARCHAR(255)

SET @OutputString = LOWER(@InputString)
SET @Index = 1

WHILE @Index <= LEN(@InputString)
BEGIN
    SET @Char     = SUBSTRING(@InputString, @Index, 1)
    SET @PrevChar = CASE WHEN @Index = 1 THEN ' '
                         ELSE SUBSTRING(@InputString, @Index - 1, 1)
                    END

    IF @PrevChar IN (' ', ';', ':', '!', '?', ',', '.', '_', '-', '/', '&', '''', '(')
    BEGIN
        IF @PrevChar != '''' OR UPPER(@Char) != 'S'
            SET @OutputString = STUFF(@OutputString, @Index, 1, UPPER(@Char))
    END

    SET @Index = @Index + 1
END

RETURN @OutputString

END
GO;
------ Re-format
SELECT distinct city, 
				[dbo].[InitCap](CASE WHEN City like 'D. %I%' then 'D.I Khan'
									when City like  'Kurram%' then 'Kuram Agency'
									when City like '%Charsadda%' then 'Charsadda'
									when City like '%,%' then TRIM(SUBSTRING(city,charindex(',',City)+1,len(City)))
									else City end)
from PakistanSuicideAttacks;


UPDATE PakistanSuicideAttacks
SET city = [dbo].[InitCap](CASE WHEN City like 'D. %I%' then 'D.I Khan'
								when City like  'Kurram%' then 'Kuram Agency'
								when City like '%Charsadda%' then 'Charsadda'
								when City like '%,%' then TRIM(SUBSTRING(city,charindex(',',City)+1,len(City)))
								else City end);

-- Province column
---- check for overlapped provinces
with cte as(
select distinct City, Province
from PakistanSuicideAttacks),
cte2 as(
select *, row_number() over( partition by city order by city) as rn
from cte)
select * from cte2 
where city in (select city from cte2 where rn >1);
---- Balochistan vs. Baluchistan, D.G Khan - Punjab*,KPK , FATA - KPK (FATA merged with KPK)
select distinct city, province,
				Case when Province = 'Baluchistan' then 'Balochistan'
					when city ='D.G Khan' then 'Punjab'
					when Province = 'FATA' then 'KPK'
					else Province end as mod_province
from PakistanSuicideAttacks;

Update PakistanSuicideAttacks
SET Province = Case when Province = 'Baluchistan' then 'Balochistan'
					when city ='D.G Khan' then 'Punjab'
					when Province = 'FATA' then 'KPK'
					else Province end;

--Other columns

---- Standardize case in open_closed_space column
Select open_closed_space, 
       upper(left(open_closed_space, 1))+SUBSTRING(open_closed_space,2,len(open_closed_Space))
from PakistanSuicideAttacks;

UPDATE PakistanSuicideAttacks
SET Open_Closed_Space = upper(left(open_closed_space, 1))+SUBSTRING(open_closed_space,2,len(open_closed_Space));

---- convert 'NA' in targeted_sect_if_any column -> NULL
select targeted_sect_if_any,
       nullif(targeted_sect_if_any,'NA')
from PakistanSuicideAttacks;

UPDATE PakistanSuicideAttacks
SET Targeted_Sect_if_any = nullif(targeted_sect_if_any,'NA');

--INACCURATE/INAPPROPRIATE DATA
select * from PakistanSuicideAttacks 
where killed_min>killed_max 
	  or open_closed_space = 'Open/Closed';
---- drop out of range/inappropriate records
Delete from PakistanSuicideAttacks
where Killed_Min>Killed_Max or open_closed_space = 'Open/Closed' ;

-- DUPLICATE CHECKS
with RowNumCTE as
(select *, row_number () over (partition by date, 
    										blast_Day_type,
                                            city,
                                            Province,
                                            Latitude,
                                            Longitude 
                                            order by date) as rn
from PakistanSuicideAttacks)
select * from RowNumCTE
where date in (select date from rownumcte where rn >1); 

-- DROP UNUSED COLUMNS
ALTER TABLE PakistanSuicideAttacks
DROP COLUMN Islamic_Date, Holiday_type, Time, Location, Influencing_Event_event, Hospital_Names, explosive_weight_max, Temperature_C,Temperature_F;


