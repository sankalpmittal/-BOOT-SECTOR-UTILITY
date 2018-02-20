.MODEL SMALL


.CODE		

ORG 7c00h	;Because BIOS loades the OS at 
			; address 0:7C00h so ORG 7C00h 
			; makes that the refrence to date 
			; are with the right offset (7c00h).
			

ProgramStart:

			
			; CS = 0 / IP = 7C00h // SS = ? / SP = ?
			; You are now at address 7c00.
jmp start	;Here we start the, BIOS gave us now the control.


xCursor db 0
yCursor db 0

;//Here goes all the data of the program.

nSector db 0
nTrack	db 0
nSide	db 0
nDrive	db 0

index	dw 0

nTrays	db 0

szReady db				'Are You Ready to start Loading the OS...',0
szErrorReadingDrive	db	'Error Reading Drive, Press any Key to reboot...',0
szPlaceMarker		db  '~~~~',0	;//Done Reading a track.
szDone				db  'Done',0

pOS		dw			7E00h

;//Disk Paremeter Table.
StepRateAndHeadUnloadTime			db	0DFh
HeadLoadTimeAndDMAModeFlag			db	2h
DelayForMotorTurnOff				db	25h
BytesPerSector						db	2h		;// (1 = 256) //(2 = 512 bytes)
SectorsPerTrack						db	18		;// 18 sectors in a track.
IntersectorGapLength				db	1Bh
DataLength							db	0FFh
IntersectorGapLengthDuringFormat	db	54h
FormatByteValue						db	0F6h
HeadSettlingTime					db	0Fh
DelayUntilMotorAtNormalSpeed		db	8h

DisketteSectorAddress_as_LBA_OfTheDataArea			db	0
CylinderNumberToReadFrom							db	0
SectorNumberToReadFrom								db	0
DisketteSectorAddress_as_LBA_OfTheRootDirectory		db	0

Start:

CLI		;Clear Interupt Flag so while setting up the stack any intrupt would not be fired.

	mov AX,7B0h		;lets have the stack start at 7c00h-256 = 7B00h
	mov SS,ax			;SS:SP = 7B0h:256 = 7B00h:256
	mov SP,256		    ;Lets make the stack 256 bytes.

	Mov ax,CS			;Set the data segment = CS = 0 
	mov DS,ax
	
	XOR AX,AX		;Makes AX=0.
	MOV ES,AX		;Make ES=0


STI     ;Set Back the Interupt Flag after we finished setting a stack fram.

	
	Call ClearScreen	;ClearScreen()
	LEA AX,szReady		;Get Address of szReady.
	CALL PrintMessage	;Call PrintfMessage()
	CALL GetKey			;Call GetKey()
	
	
	CALL SetNewDisketteParameterTable	;SetNewDisketteParameterTable()
	
	
	CALL DownloadOS
	
	CALL GetKey						;Call GetKey()
	
	CALL FAR PTR  GiveControlToOS	;Give Control To OS.
	

ret

;//////////////////////////////////////
;//Prints a message to the screen.
;//////////////////////////////////////
PrintMessage PROC

	mov DI,AX		;AX holds the address of the string to Display.
	Mov xCursor,1	;Column.
	
ContinuPrinting:

	cmp byte ptr [DI],0	;Did we get to the End of String.
	JE EndPrintingMessage	;if you gat to the end of the string return.
	
	mov AH,2			;Move Cursor
	mov DH,yCursor		;row.
	mov DL,xCursor		;column.
	mov BH,0			;page number.
	INT 10h
	INC xCursor
	
	mov AH,0Ah		;Display Character Function.
	mov AL,[DI]	;character to display.
	mov BH,0		;page number.
	mov CX,1		;number of times to write character
	INT 10h
	
	
		
	INC DI			;Go to next character.
	
	JMP ContinuPrinting		;go to Print Next Character.
		
	EndPrintingMessage:
	
	Inc yCursor			;So Next time the message would be printed in the second line.
	
	cmp yCursor,25
	JNE dontMoveCorsurToBegin 
	Mov yCursor,0
	
dontMoveCorsurToBegin:
	ret
	
		
PrintMessage EndP 
;//////////////////////////////////////
;//Watis for the user to press a key.
;//////////////////////////////////////
GetKey PROC

	mov ah,0
	int 16h ;Wait for a key press.
	Ret
	
GetKey EndP 
;//////////////////////////////////////
;//Gives Control To Second Part Loader.
;//////////////////////////////////////
GiveControlToOS PROC

	LEA AX,szDone
	Call PrintMessage
	CALL GetKey
	
	
	db 0e9h		;Far JMP op code.
	dw 512		;JMP 512 bytes ahead.
	
;	POP AX		;//Another why to make the CPU jump to a new place.
;	POP AX
;	Push 7E0h	;Push New CS address.
;	Push 0		;Push New IP address.
				;The address that comes out is 7E00:0000. (512 bytes Higher from were BIOS Put us.)
;	ret
	
	
GiveControlToOS EndP 
;//////////////////////////////////////
;//Clear Screen.
;//////////////////////////////////////
ClearScreen PROC

	mov ax,0600h	;//Scroll All Screen UP to Clear Screen.
	mov bh,07
	mov cx,0
	mov dx,184fh	
	int 10h
	
	Mov xCursor,0	;//Set Corsur Position So next write would start in the beginning of screen.
	Mov yCursor,0

	Ret
	
ClearScreen EndP
;//////////////////////////////////////
;//PrintPlaceMarker.
;//////////////////////////////////////
PrintPlaceMarker PROC


	LEA AX,szPlaceMarker
	CALL PrintMessage	;Call PrintfMessage()
	CALL GetKey			;Call GetKey()
	ret
	
PrintPlaceMarker EndP
;//////////////////////////////////////
;//Set New Disk Parameter Table
;//////////////////////////////////////
SetNewDisketteParameterTable PROC

	LEA DX,StepRateAndHeadUnloadTime
	

	
	
									;//Int 1E (that is in address 0:78h) 
									;//holds the address of the disk parametrs 
									;//block, so now change it to 
									;//our parametr black.
	MOV WORD PTR CS:[0078h],DX		;//DX holds the address of our Paramer block.
	MOV WORD PTR CS:[007Ah],0000
	

	MOV AH,0    ;Reset Drive To Update the DisketteParameterTable.
	INT 13H
	
	
	ret
	
	
SetNewDisketteParameterTable EndP
;//////////////////////////////////////
;//DownloadOS
;//////////////////////////////////////
DownloadOS PROC

	mov nDrive,0
	mov nSide,0
	mov nTrack,0
	mov nSector,1
	
ContinueDownload:
	
	INC nSector			;Read Next Sector.
	cmp nSector,19		;Did we get to end of track.
	JNE StayInTrack
	CALL PrintPlaceMarker
	INC nTrack			;If we gat to end of track Move to next track.
	mov nSector,1		;And Read Next Sector.
	CMP nTrack,5		;Read 5 Tracks (Modify this value to how much Tracks you want to read).
	JE	EndDownloadingOS
	
StayInTrack:
	
	;CALL PrintPlaceMarker

	;ReadSector();
	Call ReadSector
	
	
	JMP	ContinueDownload	;If diden't yet finish Loading OS.
	
EndDownloadingOS:

	ret
	
DownloadOS EndP 
;//////////////////////////////////////
;//Read Sector.
;//////////////////////////////////////
ReadSector PROC

	mov nTrays,0
	
TryAgain:

	mov AH,2		;//Read Function.
	mov AL,1		;//1 Sector.
	mov CH,nTrack
	mov CL,nSector	;//Remember: Sectors start with 1, not 0.
	mov DH,nSide
	mov DL,nDrive
	Mov BX,pOS		;//ES:BX points to the address to were to store the sector.
	INT 13h
	

	CMP AH,0			;Int 13 return Code is in AH.
	JE EndReadSector	;if 'Sucsess' (AH = 0) End function.

	mov AH,0			;Else Reset Drive . And Try Again...
	INT 13h
	cmp nTrays,3		;Chack if you tryed reading more then 3 times.
	
	JE DisplayError		; if tryed 3 Times Display Error.
	
	INC nTrays
	
	jmp TryAgain       ;Try Reading again.
	
DisplayError:
	LEA AX,szErrorReadingDrive
	Call PrintMessage
	Call GetKey
	mov AH,0			;Reboot Computer.
	INT 19h
	

EndReadSector:
	;ADD WORD PTR pOS,512	;//Move the pointer (ES:BX = ES:pOS = 0:pOS) 512 bytes.
							;//Here you set the varible pOS (pOS points to were BIOS 
							;//Would load the Next Sector).
	Ret
	
ReadSector EndP 
;//////////////////////////////////////
;//
;//////////////////////////////////////
END ProgramStart 
