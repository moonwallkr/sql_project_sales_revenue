--Part D.
--Raw Data
Select * From payment; --payment_id, amount
Select * From rental; --rental_id
Select * From inventory; --inventory_id
Select * From film_category; --film_id
Select * From film;--rental_rate, replacement_cost
Select * From category; --name
Select * From store; --store_id,
Select * From staff; --staff_id, store_id
Select SUM(amount) From payment; --61312.04
--Part D
--detailed sales report
Select s.store_id,
	r.rental_id,
	 p.amount, p.payment_id,
	f.rental_rate, f.replacement_cost,
	i.inventory_id,
	fc.film_id,
	c.name
From store s
Left Join staff st ON s.store_id = st.store_id
Left Join payment p On st.staff_id = p.staff_id
Left Join rental r On p.rental_id = r.rental_id
Left Join inventory i On r.inventory_id = i.inventory_id
Left Join film f On i.film_id = f.film_id
Left Join film_category fc On f.film_id = fc.film_id
Left Join category c On fc.category_id = c.category_id;

--Part D
--Updated summary report
--Showing store_id, genre, total_sales, and total_revenue
Select p.staff_id as store_id, 
	c.name as genre,
	Count(p.payment_id) as total_sales,
	SUM(p.amount) :: money as total_revenue --PART A4. USING CASTING TO MAKE $ AND ','From payment p
Left Join rental r on p.rental_id = r.rental_id
Left Join inventory i On r.inventory_id = i.inventory_id
Left Join film f On i.film_id = f.film_id
Left Join film_category fc On f.film_id = fc.film_id
Left Join category c On fc.category_id = c.category_id
Group By p.staff_id, c.name
Order By p.staff_id, total_revenue Desc;

--Part C--This creates my tables
Create Or Replace Procedure create_sales_tables()
Language plpgsql
As $$
Begin
	Drop Table If Exists detailed_report;
	Drop Table If Exists summary_report;

Create Table detailed_report AS
Select s.store_id,
	r.rental_id,
	 p.amount, p.payment_id,
	f.rental_rate, f.replacement_cost,
	i.inventory_id,
	fc.film_id,
	c.name
From store s
Left Join staff st ON s.store_id = st.store_id
Left Join payment p On st.staff_id = p.staff_id
Left Join rental r On p.rental_id = r.rental_id
Left Join inventory i On r.inventory_id = i.inventory_id
Left Join film f On i.film_id = f.film_id
Left Join film_category fc On f.film_id = fc.film_id
Left Join category c On fc.category_id = c.category_id;

Create Table summary_report AS
Select p.staff_id as store_id, 
	c.name as genre,
	Count(p.payment_id) as total_sales,
	SUM(p.amount) :: money as total_revenue --PART A4. USING CASTING TO MAKE $ AND ','	From payment p
Left Join rental r on p.rental_id = r.rental_id
Left Join inventory i On r.inventory_id = i.inventory_id
Left Join film f On i.film_id = f.film_id
Left Join film_category fc On f.film_id = fc.film_id
Left Join category c On fc.category_id = c.category_id
Group By p.staff_id, c.name
Order By store_id, total_revenue Desc;

Return;
End;
$$;

--BEGIN CREATE TABLE TEST
CALL create_sales_tables(); --Calling this created the two tables for me from the visualized data I coded up above.

Select SUM(amount) From detailed_report; --61312.04
Select * From summary_report; --32 rows
Select SUM(total_revenue) From summary_report; --61312.04
--END CREATE TABLE TEST

--Part F
--Refreshes both the summary and detailed report
Create Or Replace Procedure refresh_sales_tables()
Language plpgsql
As
$$
Begin
	Delete From detailed_report;
	Delete From summary_report;

	Insert Into detailed_report
	Select s.store_id,
	r.rental_id,
	 p.amount, p.payment_id,
	f.rental_rate, f.replacement_cost,
	i.inventory_id,
	fc.film_id,
	c.name
From store s
Left Join staff st ON s.store_id = st.store_id
Left Join payment p On st.staff_id = p.staff_id
Left Join rental r On p.rental_id = r.rental_id
Left Join inventory i On r.inventory_id = i.inventory_id
Left Join film f On i.film_id = f.film_id
Left Join film_category fc On f.film_id = fc.film_id
Left Join category c On fc.category_id = c.category_id;


Insert Into summary_report
Select  store_id, 
	name as genre,
	Count(payment_id) as total_sales,
	SUM(amount) :: money as total_revenue --PART A4. USING CASTING TO MAKE $ AND ','	From detailed_report
Group By store_id, name
Order By store_id, total_revenue Desc;


Return;
End;
$$;

--BEGIN REFRESH TEST
Select * From detailed_report;--14596
Select Count(*) From detailed_report; --14596
Select SUM(total_sales) From summary_report; --14596

Delete From detailed_report Where store_id = '2'; --only left with 7292 rown when running Count above.

Select COUNT(*) From detailed_report; 7292

Call refresh_sales_tables(); --restores tables to 14596 rows

Select Count(*) From detailed_report; --14596 again
Select SUM(amount) :: money From detailed_report; --$61,312.04
Select Sum(total_revenue) :: money From summary_report; -- $61,312.04
--END REFRESH TEST

--PART B & A4: 
--CASTING "MONEY" to get the "$" and "," where needed for readability.
--updates everything in the summary_table so when there is new data entered into the detail_table, 
--it remains fresh in the summary table as well.
Create or Replace Function insert_trigger_function()
	Returns Trigger --insert_trigger
	Language plpgsql
As
$$
Begin
	Delete From summary_report; --clears out table
	Insert Into summary_report
	Select  store_id, 
	name as genre,
	Count(payment_id) as total_sales,
	SUM(amount) :: money as total_revenue --PART A4. USING CASTING TO MAKE $ AND ','.
	From detailed_report
	Group By store_id, name
	Order By store_id, total_revenue Desc;
Return New; --Returns the new information
End;
$$;

--PART E
--For each statement runs for JUST each command
Create Or Replace Trigger insert_trigger
	After Insert --after insert of new data
	On detailed_report
	For Each Statement --so it doesnt trigger each row and take longer than needed.
	Execute Procedure insert_trigger_function(); --executes the function I created

--Testing trigger
SELECT * FROM detailed_report;
Select Count(*) from detailed_report; --14596
Select Sum(total_sales) From summary_report; --14596

Insert Into detailed_report VALUES ('3', '8481', '10.99', '51504', '5.99', '15.99', '9000', '3100', 'Indie'); --will show 14597

Select COUNT(*) From detailed_report; --14597 (correct)
Select SUM(total_sales) From summary_report; --14597 (correct)
Select * From summary_report; --Shows a 3rd store and the values
--End Testing Trigger

--PART E
--This function will update the data in the summary_table
--as it is updated in the detail table.
Create Or Replace Function update_trigger_function()
	Returns Trigger
	Language plpgsql
As
$$
Begin
	Delete From summary_report; --refreshes summary_table when updating information on the detail_table.
	Insert Into summary_report
	Select  store_id, 
	name as genre,
	Count(payment_id) as total_sales,
	SUM(amount) :: money as total_revenue
	From detailed_report
	Group By store_id, name
	Order By store_id, total_revenue Desc;
Return New;
End;
$$;

Create Or Replace Trigger update_trigger
	After Update
	On detailed_report
	For Each Statement --to save time and nopt bog down the system by going by row.
	Execute Procedure update_trigger_function();

--BEGIN Testing trigger Update
Select * From detailed_report Where store_id = '3'; --Shows the store 3
Select COUNT(*) From detailed_report Where store_id = '3'; -- Shows store 3
Select * From summary_report; --Shows updated summary_table for store 3.

Update detailed_report
Set  store_id = '4'
Where store_id = '3';

Select * From summary_report; --Shows the store_id has been updated to 4
--END Testing Trigger Update

--PART E
--Created a trigger to delete information on summary table when deleted from the deail table
--I wanted to able to delete the test information i submitted into the tables more efficiently.
Create Or Replace Function delete_trigger_function()
	Returns Trigger
	Language plpgsql
As
$$
Begin
	Delete From summary_report; --refreshes summary_table when updating information on the detail_table.
	Insert Into summary_report
	Select  store_id, 
	name as genre,
	Count(payment_id) as total_sales,
	SUM(amount) :: money as total_revenue
	From detailed_report
	Group By store_id, name
	Order By store_id, total_revenue Desc;
Return New;
End;
$$

Create Or Replace Trigger delete_trigger
	After Delete
	On detailed_report
	For Each Statement --to save time and not bog down the system by going by row.
	Execute Procedure delete_trigger_function();
	
--BEGIN Testing Delete Trigger
Select * From summary_report; -- Shows store 4
Select * From detailed_report where store_id = '4'; -- Shows store 4 details

Delete From detailed_report
Where store_id = '4';

Select * From summary_report; --Shows store 4 is gone
Select COUNT(*) from detailed_report; --Shows total records are 14596 again.
--END Testing Delete Trigger

--And Just to show how to drop the triggers and on which tables
Drop Trigger if exists update_trigger On detailed_report;
Drop Trigger If exists insert_trigger On detailed_report;
Drop Trigger If Exists delete_trigger On detailed_report;
