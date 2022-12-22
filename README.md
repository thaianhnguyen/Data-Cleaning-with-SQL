# Data cleaning with SQL
[__My SQL queries script here__]() </br>
In this project, I will be cleaning data concerning Pakistan's suicidal bombing from 1997-2017. The desired outcome would be to provide a clean dataset ready for the analysis of the pattern of bombings in terms of day type, location, target as well as deadliness. </br>
The dataset was collected from [__here.__](https://www.kaggle.com/datasets/zusmani/pakistansuicideattacks?datasetId=719&sortBy=voteCount)

The Dataset has 496 records and 26 columns, but we only use 17 of them.</br>

Table of contents
=================

<!--ts-->
* [Re-format the date column](#re-format-the-date-column)
* [Filling the null values](#null)
* [Standardize inconsistent data entries](#data-entry) </br>
    * [City Column](#city) </br>
    * [Province Column](#province)</br>
    * [Other Columns](#other)</br>
 * [Inaccurate/ inappropriate data](#inaccurate)
 * [Duplicate values](#duplicate)
<!--te-->
<a name="re-format-the-date-column"/> </br>
## Re-format the date column
The Date column is string and has complex formats. Therefore, I will make some transformations before converting it into date type.

```sql
-- Re-format the date column from string to date
Select Date, 
	   CAST(REPLACE(RIGHT(Date, LEN(Date)-CHARINDEX('-',Date)),'-', ' ') AS DATE) as newdate
from PakistanSuicideAttacks;

UPDATE PakistanSuicideAttacks
SET Date = CAST(REPLACE(RIGHT(Date, LEN(Date)-CHARINDEX('-',Date)),'-', ' ') AS DATE);
-- Set data type of column into Date type
ALTER TABLE PakistanSuicideAttacks
ALTER COLUMN  Date Date;
```
![date column](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_1.jpg)

<a name="null"/> </br>
## Filling the null values
In 17 used columns, there are some with null values. However, only Blast_day_type column is rectifiable. </br>
The logic is that if a day in any year is holiday, that day in other year will be holiday too. If a day is not a holiday, it could be Weekend or Workday, depending on its day of week. 
```sql
-- Filling null values of Blast_day_type columns

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
					where Blast_Day_Type = 'Holiday')		 	  then 'Holiday' 
	 when DATEPART(weekday,date) % 7 in (1,0)
	 then 'Weekend'
	 else 'Working Day' end 
    where Blast_Day_Type is null;
``` 
![blast_day_type column](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_2.jpg)

<a name="data-entry"/> </br>
## Standardize the inconsistent data entry. 
<a name="city"/> </br>
### City Column
There are several columns in this dataset that has the problem of inconsistent data entry. The most complex one is the City Column. </br>
After querying distinct records and check for mispronounced names by SOUNDEX functions, I discovered that records in this field are subject to these following problems:
* Inconsistent Case (e.g. _Bannu_ vs. _bannu_)
* Typo or mispronounced (e.g. _D.I Khan_ vs _D. I Khan_; _Kuram_ vs. _Kurram_)
* Too specific information (e.g. _Ghallanai, Mohmand Agency_ vs. _Mohmand Agency_) </br>
For the first problem, I want to capitalize the first character of each words. However, there is no built-in function for it; therefore,  I utilized a user-defined function namely InitCap, you can refer to it [here](http://www.sql-server-helper.com/functions/initcap.aspx). For other problems, I will utilize CASE WHEN to solve.
``` sql 
----  manually check distinct values of city 
select distinct city
from PakistanSuicideAttacks;
-- inconsistent cases, "D.I Khan", too specific info like "Ghallanai, Mohmand Agency" -, mispronounced "Kuram" and "Kuram"

---- double check for any other mispronounced city names 
select distinct t1.city
from PakistanSuicideAttacks t1
inner join PakistanSuicideAttacks t2
on SOUNDEX(replace(t1.city,' ','')) = SOUNDEX(replace(t2.city,' ',''))
and t1.city <> t2.city;

---- FIX THE PROBLEMS
SELECT distinct city, 
       [dbo].[InitCap](CASE WHEN City like 'D. %I%' then 'D.I Khan'
			    when City like  'Kurram%' then 'Kuram Agency'
			    when City like '%Charsadda%' then 'Charsadda'
			    when City like '%,%' then TRIM(SUBSTRING(city,charindex(',',City)+1,len(City)))
			    else City end)
from PakistanSuicideAttacks;


UPDATE PakistanSuicideAttacks
SET city =
    [dbo].[InitCap](CASE WHEN City like 'D. %I%' then 'D.I Khan'
   			 when City like  'Kurram%' then 'Kuram Agency'
			 when City like '%Charsadda%' then 'Charsadda'
			 when City like '%,%' then TRIM(SUBSTRING(city,charindex(',',City)+1,len(City)))
			 else City end);
```
![City column](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_3.jpg)

<a name="province"/> </br>
### Province Column
The problem of this column is that some cities are recorded for two provinces. I have isolated these cases with the following queries:
```sql
with cte as(
select distinct City, Province
from PakistanSuicideAttacks),
cte2 as(
select *, row_number() over( partition by city order by city) as rn
from cte)
select * from cte2 
where city in (select city from cte2 where rn >1)
```
![one city two provinces](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_4.jpg) </br>
After researching, I found out that this problem is mainly due to the fact that KPK province merged with FATA province. And for Balochistan/Baluchistan, they are just two different ways of spelling for the same province. There is one case of incorrect date input though, which is D.G Khan.
```sql
---- Balochistan vs. Baluchistan; D.G Khan - (Punjab*,KPK) ; FATA - KPK (FATA merged with KPK)
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
```
<a name="other"/> </br>
### Standardize other columns
```sql
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
``` 

<a name="inaccurate"/> </br>
## Inaccurate/ inappropriate data
Some data was found inappropriate.
* Value in _Killed_min_ is greater than that of _Killed_max_ for 2 records
* There is one 'Open/Closed' value in Open_Closed_Space
![inappropriate data](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_5.jpg) </br>
Because there are only 3 records with inappropriate data, I will drop them.
```sql
---- drop out of range/inappropriate records
Delete from PakistanSuicideAttacks
where Killed_Min>Killed_Max or open_closed_space = 'Open/Closed';
```
<a name="duplicate"/> </br>
## Duplicate values
For this duplication test, I will only use the cleaned columns or columns that are not subject to inconsistent data entry as input inconsistencies can cause inaccuracies in the results.</br>
The result shows that although there are 6 duplicate records based on selected columns, it is duplication with discrepancies in some other columns, especially important ones that will certainly affect the analysis like _Killed_Min_, _Killed_Max_ column. </br>
```sql
---- check for duplicate records with columns that are going to be use
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
``` 
![duplicate test](https://github.com/thaianhnguyen/Data-Cleaning-with-SQL/blob/main/Images/Screenshot_6.jpg)</br>
The problem can be dealt with as follows:</br>
* With further research, we can determine which record is the _true_ duplicate one or which is another bombing that happens at the same time, the latter of which we will keep.
* For the duplicate records with different values in qualitative fields like _Killed_Min_, _Killed_Max_, we might use the mean value if two values in the same field conflict or simply keep one if the other value is null. </br>

However, due to the scope of the project, I would not be able to verify those duplicate values. Therefore, it is such regret not to provide the final cleaned data. </br>
After dropping unused columns, the final data has 493 records and 17 columns.

You can visit [__My SQL queries script here.__]() </br>
 
