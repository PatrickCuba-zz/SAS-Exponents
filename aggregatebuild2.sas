options source2;
Libname AggDemo "~/AggregateDemo";

Filename OUTL Catalog "AggDemo.Aggregate.SQL.Source";
Filename OUTM Catalog "AggDemo.Aggregate.INDEX.Source";

* Create Combo Table ;
Data Fmt;
	Keep Start Label Fmtname;
	Infile Cards ;
	Input Label : $10.;
	Retain Max;
	Start=2**(_n_-1);
	Fmtname='BuildAggre';
	Max=Sum(Max, Start);
	Call SymputX('Max', Max);
	Cards;
ACC
CUST
PROD
DATE
;
Run;

Proc Format Cntlin=Fmt;
Quit;

* CREATE COLUMN LISTS FOR EACH DIMENSION ;
Data Dimcolumns;
	Infile Cards DLM=',';
	Input Dim    : $10.
          Column : $32.
		  ;
	Cards;
ACC, ACCOUNT_DIM_KEY
ACC, ACCOUNTCAT
CUST, CUSTOMER_DIM_KEY
CUST, CUSTOMER_NAME
PROD, PRODUCT_DIM_KEY
PROD, PRODUCT_NAME
DATE, DATE_DIM_KEY
;
Run;
Proc Sort Data=DimColumns;
	By dim;
Run;
Data Fmt;
	Keep Start Label Fmtname;
	Length Start $32.;
	Set DimColumns End=End;
	By Dim;

	Retain Fmtname '$Columnlist' Label;

	If First.Dim Then Do;
		Start=Dim;
		Label=Column;
		Output;
	End;
	Else Do;
		Start=Label;
		Label=Column;
		Output;
	End;
	If Last.Dim Then Do;
	    Start=Label;
		Label='XXX';
		Output;
	End;
	If End Then Do;
		HLO='o';
		Start=' ';
		Label='XXX';
		Output;
	End;
Run;
Proc Format Cntlin=Fmt;
Quit;

* CREATE LIST OF DIMENSION TABLES ;
Data Fmt;
	Infile Cards DLM=',';
	Input Start : $10.
	      Label : $32.
		  ;
	Fmtname='$Tablelist';
	Cards;
ACC, DIM_ACCOUNT
CUST, DIM_CUSTOMER
PROD, DIM_PRODUCT
DATE, DIM_DATE
;
Proc Format Cntlin=Fmt;
Quit;

/*%LET MAX=16;*/
%Let OutLength=$%Sysfunc(Min(%Eval(1000*&Max.), 5000));

%Put NOTE: &Max. &OutLength.;
Data Combinations;
	Keep Outstring Tablename Columnstring Dimtable Whereclause Groupby Columnstring1 Indexlist;
	Length Outstring Columnstring Columnstring1 Indexlist Dimtable Whereclause Groupby &Outlength. Out $100. ID $6.;
	Expo=&Max.;
	* loop to create column list ( 1 to 5) ;

	Do i = 1 To &Max.;
	    Outstring='';
		Columnstring='';
		Columnstring1='';
		Indexlist='';
	    Factor=i;
		Dimtable='';
    	Whereclause='';
		Groupby='';
		* LOOP TO CREATE COMBINATIONS ;
		Do j = 1 To &Max.;
			Binary=2**(Expo-j);
			ID=Compress('DIM'||Put(i, Z3.));
			If Factor >= Binary Then Do;
			    Out=Put(Binary, BuildAggre.);
				OutString=Strip(CompBL(OutString||' '||Out));
				Factor=Sum(Factor, -1*Binary);
				* BUILD COLUMN LIST, WHERE AND GROUP BY CLAUSE, INDEX LIST;
				Do Until(Put(Out,$ColumnList.)='XXX');
					Out=Put(Out,$ColumnList.);
                    If Index(Out,'KEY') Then Do;
						Whereclause=CompBL(Whereclause||'And FACT.'||Out||'='||ID||'.'||Out);
					End;
					If Groupby > ' ' Then  Groupby=CompBL(Groupby||','||Out);
					Else Groupby=CompBL(Groupby||Out); 
                    Columnstring=CompBL(Columnstring||', '||ID||'.'||Out);
					Columnstring1=CompBL(Columnstring1||', '||Out);
					IndexList=CompBL(IndexList||' '||Out);
				End;
				* BUILD DIMENSION TABLE LIST ;
				Out=Put(Put(Binary, BuildAggre.),$TableList.);
				DimTable=CompBL(DimTable||', '||Out||' '||ID);
			End;
		End;
		TableName=Translate(Strip(OutString),'_',' ');
		Output;
	End;
Run;
filename outf1 '~/AggregateDemo/comb.xls';
proc export data=combinations file=outf1 dbms=xls replace;
run;
* OUTPUT TO CATELOG ENTRY ;
Data _Null_;
	File OUTL LRECL=28000;
	Set Combinations End=End;

	If _N_=1 Then Put 'Proc SQL Noprint;';
	Put 'Create Table Mth_' Tablename ' as ';
	Put 'Select Distinct Amount';
    Put '       ' Columnstring ;
	Put 'From Fact_Balance Fact' Dimtable;
	Put 'Where 1=1 ' Whereclause ';';
	Put 'Create Table Ag_Mth_' Tablename ' As ';
	Put 'Select Sum(Amount) As Amount';
    Put '       ' Columnstring1 ;
	Put 'From Mth_' Tablename;
	Put 'Group By ' Groupby ';';
	If End Then Put 'Quit;';
RUN;

* RUN GENERATED CODE ;
 %Inc OUTL; 

Data _Null_;
	File OUTM LRECL=28000;
	Set Combinations End=End;
	If _N_=1 Then Put 'Proc Datasets Lib=Work Nolist Nodetails;';
    Put 'Modify AG_Mth_' Tablename ' ;';
    Put 'Index Create ' Indexlist ';';
	If End Then Put 'Quit;';
Run;

%INC OUTM; 

Proc Datasets Lib=Work Nolist Nodetails;
	Delete Mth_: Fmt Dimcolumns;
Quit;
