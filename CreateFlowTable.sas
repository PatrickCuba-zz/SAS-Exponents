/* Control Table */
Libname FlowCntl "~/Flow";
Libname Library '~/';
Data FMT;
	FMTNAME='Trigger_Dependancy';
	Start=.;
	Label='Undefined';
	HLO='O';
Run;
Proc Format Cntlin=FMT Library=Library;
Proc Datasets Lib=Work Nolist Nodetails;
	Delete FMT;
Quit;


Data FlowCntl.Flow_Control_Table;
	Infile Cards DSD DLM=',';
	Input Flow_ID     : 8.
	      Flow_Name   : $256.
	      Flow_Dep_ID : 8.
	      Flow_Status : $10.
	      ;
	Bin=2**(Flow_ID-1);
	Flow_Upd_Dtm=.;
   	Format BIN Trigger_Dependancy. Flow_Upd_Dtm DateTime22.;   
	Cards;
1, Load Core Tables, ., Complete
2, Load Secondary Tables, ., Complete
3, Load Reconciliations, ., Complete
4, Load Subject Area Marts, ., Complete
5, Load Legacy Data, ., Complete
6, Load Policy Checks, ., Complete
7, Load Presentation Layer, ., Complete
8, Load Report Lookup Tables, ., Complete
9, Refresh Reports, ., Complete
;
Run;

/* Add Integrity Constraints to Table */
Proc Datasets Lib=FlowCntl NoList Nodetails;
	Modify Flow_Control_Table;
	IC Create Unique_FID  = Unique(Flow_ID);
	Index Create Flow_Name/Unique;
	IC Create VAL_Status=Check(Where=(Flow_Status In ('Complete' 'Running' '')));
Quit;

/* Update Dependencies */
%FlowManagement(Flow_Name=Load Reconciliations, Dependancy=Load Core Tables, Status=Complete, Action=UPD);
%FlowManagement(Flow_Name=Load Subject Area Marts, Dependancy=Load Core Tables, Status=Complete, Action=UPD);
%FlowManagement(Flow_Name=Load Policy Checks, Dependancy=Load Subject Area Marts|Load Legacy Data, Status=Complete, Action=UPD);
%FlowManagement(Flow_Name=Load Presentation Layer, Dependancy=Load Reconciliations|Load Policy Checks, Status=Complete, Action=UPD);


%FlowManagement(Flow_Name=Load Secondary Tables, Dependancy='', Status=Complete, Action=UPD);
%FlowManagement(Flow_Name=Load Legacy Data, Dependancy='', Status=Complete, Action=UPD);



