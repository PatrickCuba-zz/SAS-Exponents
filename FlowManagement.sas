
/* Manage
1. Add NEW         : NEW Flow_Name, Dependancy (Optional) PIPE Delimited - Autoadd ID
2. Update EXISTING : UPD Flow_name, Dependancy (Optional) PIPE Delimited Status (Optional)
3. Remove EXISTING : DEL Flow_Name

*/

/* Stored Process to Manage the Control Table */
/* Update format to show dependancies  */
%Macro FlowManagement(Flow_Name=, Dependancy=, Status=, Action=);

	Libname FlowCntl "~/Flow";

	/* Error Traps */
	%Let Error=0;

	%If &Flow_Name.= 
		Or &Action.= %Then %Do;
		%PUT WARNING: Flow name or Action not specified;
		
		Data _NULL_;
			Set FlowCntl.Flow_Control_Table;
			Put _ALL_;
		Run;
		
		%Let Error=1;
	%End;
	
	%If &Error. %Then %Goto EndofMac;
	
	/* Processing */
	/* Add */
	%If &Action.=ADD %Then %Do;
		/* New Record needs a new Flow_ID = Max+1 */
		Proc SQL Noprint;
			Select Max(Flow_ID) Into :Max_Flow_ID From FlowCntl.Flow_Control_Table;
		Quit;
		Data __Add_to_Cntl;
			IF _N_=0 Then Do;
				Set FlowCntl.Flow_Control_Table;
				Stop;
			End;
			
			/* Hash is needed to retrieve Bin by Flowname */
			/* Bin is added to Flow_Dep_ID                */
			If _N_=1 Then Do;
				Declare Hash _FindDep(Dataset: 'FlowCntl.Flow_Control_Table', Ordered:'Yes');
				_FindDep.DefineKey('Flow_Name');
				_FindDep.DefineData('Bin');	
				_FindDep.DefineDone();			 
			End;
			
			/* New Flow ID */
			Flow_ID=&Max_Flow_ID.+1;
			
			/* Look for dependancies */
			/* Loop through PIPEs    */
			Flow_Dep_ID=0;
			Loops=Sum(Count("&Dependancy.","|"), 1);
			Do Loop_Iter=1 To Loops;
				/* By defined name find the Binary value, add to Dependancy */
				Flow_Name=Scan("&Dependancy.",Loop_Iter,"|");
				RC=_FindDep.Find();
				IF ^RC Then Flow_Dep_ID=Sum(Flow_Dep_ID, BIN);
			End;
			/* Result should be a binary value that can later be broken down to decipher dependant flows */
			
			/* Set flow values & Status */
 			Flow_Name="&Flow_Name."; 
 			Bin=2**(Flow_ID-1); 
 			Flow_Status="&Status.";
 			
 			Drop RC Loops Loop_Iter;
		Run;
		Proc Append Base=FlowCntl.Flow_Control_Table Data=__Add_to_Cntl;
		Quit;
		Proc Datasets Lib=Work NoList Nodetails;
			Delete __Add_to_Cntl;
		Quit;
	%End;
	
	/* Update*/
	%If &Action.=UPD %Then %Do;
		Data __Update_Cntl;
			Set FlowCntl.Flow_Control_Table;
			
			If _N_=1 Then Do;
				Declare Hash _FindDep(Dataset: 'FlowCntl.Flow_Control_Table', Ordered:'Yes');
				_FindDep.DefineKey('Flow_Name');
				_FindDep.DefineData('Bin');	
				_FindDep.DefineDone();			 
			End;
						
			/* Look for dependancies */
			/* Loop through PIPEs */
			Flow_Dep_ID=0;
			Loops=Sum(Count("&Dependancy.","|"), 1);
			Do Loop_Iter=1 To Loops;
				Flow_Name=Scan("&Dependancy.",Loop_Iter,"|");
				RC=_FindDep.Find();
				IF ^RC Then Flow_Dep_ID=Sum(Flow_Dep_ID, BIN);
			End;
			
 			Flow_Name="&Flow_Name."; 
 			Bin=2**(Flow_ID-1); 
 			Flow_Status="&Status.";
 			
 			/* Only update for existing Flow */
 			Where Flow_Name="&Flow_Name.";
 			
 			Drop RC Loops Loop_Iter;
		Run;
 		Data FlowCntl.Flow_Control_Table;
 			Set __Update_Cntl(Rename=(Flow_Status=_Flow_Status Flow_Dep_ID=_Flow_Dep_ID));
 			Modify FlowCntl.Flow_Control_Table Key=Flow_Name;
 			If _IORC_ = %Sysrc(_SOK) Then Do;
 			    Flow_Status=_Flow_Status;
 			    Flow_Dep_ID=_Flow_Dep_ID;
 			    Replace;
            End;  
 		Run;
 		Proc Datasets Lib=Work NoList Nodetails;
 			Delete __Update_Cntl; 
		Quit;	 
	
	%End;
	
	/* Delete */
	%If &Action.=DEL %Then %Do;
		Proc SQL NoPrint;
			Delete from FlowCntl.Flow_Control_Table Where Flow_Name="&Flow_Name.";
		Quit;
		%If &SQLOBS.=0 %Then %Put WARNING: Nothing Deleted;
		%Else %Do;
			/* Rebuild Control Table with correct IDs and BINS */
		    Data _Rebuild_Cntl;
				Set FlowCntl.Flow_Control_Table(Drop=Flow_ID);

				Flow_ID+1;
				Bin=2**(Flow_ID-1);
			Run;
			Proc SQL NoPrint;
				Delete From FlowCntl.Flow_Control_Table;
			Quit;
			Proc Append Base=FlowCntl.Flow_Control_Table Data=_Rebuild_Cntl;
			Quit;
			Proc Datasets Lib=Work Nolist Nodetails;
				Delete _Rebuild_Cntl;
			Quit;
		%End;
	%End;
	
	/* Update Format */
	
	Data FMT;
		Keep Start Label FMTName HLO;
	
		If _N_=1 Then Do;
			Declare Hash _FindDep(Dataset: 'FlowCntl.Flow_Control_Table', Ordered:'Yes');
			_FindDep.DefineKey('Flow_ID');
			_FindDep.DefineData('BIN', 'Flow_Name');	
			_FindDep.DefineDone();
			
			Declare Hiter _IterFinDep('_FindDep');			 
		End;
		
		Length Label $256.;
		
		Set FlowCntl.Flow_Control_Table End=End;
		
		Retain FMTNAME 'Trigger_Dependancy';
		
		Start=BIN;
		
		/* Whatever the record, go to the last record in memory     */
		/* Current Dependant record maybe 18, next BIN should be 16 */
		
 		_Flow_Dep_ID=Flow_Dep_ID; 

 		RC=_IterFinDep.Last();
 		 		
 		Do Until(RC^=0); 
 			If _Flow_Dep_ID>=BIN Then Do;
 				_Flow_Dep_ID=Sum(_Flow_Dep_ID, -1*BIN); 
 				Label=Strip(CompBL(Label||'|'||Flow_Name));
 			End;
 			RC=_IterFinDep.Prev(); 
 		End; 
 		
 		Label=Substr(Label,2);
        If Label='' Then Label='Start'; 
 		
 		Output;
 		If End Then Do;
 			Start=.;
 			Label='Start';
 			HLO='O';
 			Output;
 		End;
 		
 		Where Flow_Dep_ID ne .;
	Run;
	Proc Format Cntlin=FMT Library=Library;
	Quit;
	Proc Datasets Lib=Work Nolist Nodetails;
 		Delete FMT; 
	Quit;

	Libname FlowCntl Clear;

%EndofMac:
	%If &Error. %Then %Put NOTE: Nothing to Process;

%Mend;


/* Trigger Macro to interact with the Control Table from the Flow */
/* Determines that the dependant jobs have completed  */