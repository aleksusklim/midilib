unit UMidiLib;

interface

uses
  UCachedList;

const
  ID_MThd = 1684558925;
  ID_MTrk = 1802654797;

type
  TMidiTrack = class(TCachedListElem)
    constructor Create();
    destructor Destroy(); override;
  public
    function GetSize(): Integer;
    procedure Clear();
    function ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
    function EncodeTo(var SaveTo: Pointer): Integer;
    function FilterSys(): Integer;
    function FilterText(): Integer;
  public
    Events: TCachedList;
  end;

type
  TMidiEvent = class(TCachedListElem)
    destructor Destroy(); override;
  public
    function IsSystem(): Boolean;
    function IsMeta(): Boolean;
    function IsChannel(): Boolean;
    function TwoParams(): Boolean;
    function IsText(): Boolean;
    function GetSize(): Integer;
    procedure Clear();
    function ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
    function EncodeTo(var SaveTo: Pointer): Integer;
  public
    DeltaTime: Integer;
    EventType: Byte;
    Param1, Param2: Byte;
    MetaType: Byte;
    MetaLength: Integer;
    MetaData: Pointer;
  end;

type
  TMidiFile = class(TObject)
  public
    procedure Clear();
    function Open(FileName: string): Boolean; overload;
    function Open(var RawMidi: Pointer; var HaveSize, TotalSize: Integer): Boolean; overload;
    function Save(FileName: string): Integer; overload;
    function Save(var SaveTo: Pointer): Integer; overload;
    function GetSize(): Integer;
    function FilterSys(): Integer;
    function FilterText(): Integer;
  public
    FormatType: Integer;
    TimeDivision: Integer;
    Tracks: TCachedList;
  end;

implementation

uses
  Classes, SysUtils, Math;

type
  TRawMidiHeader = packed record
    Id: Integer;
    Size: Integer;
    Format: Word;
    Tracks: Word;
    Time: Word;
    Data: Integer;
  end;

  PRawMidiHeader = ^TRawMidiHeader;

type
  TRawMidiTrack = packed record
    Id: Integer;
    Size: Integer;
    Data: Integer;
  end;

  PRawMidiTrack = ^TRawMidiTrack;

type
  TRawMidiEvent = packed record
    Id: Integer;
    Size: Integer;
    Data: Integer;
  end;

  PRawMidiEvent = ^TRawMidiEvent;

function LittleWord(Big: Word): Word;
begin
  Result := $ffff and ((Big shr 8) or (Big shl 8));
end;

function LittleInteger(Big: Integer): Integer;
begin
  Result := (Big shl 24) or (Big shr 24) or ((Big shr 8) and $ff00) or ((Big shl 8) and $ff0000);
end;

function VarLenRead(var Data: Pointer; var HaveSize, TotalSize: Integer): Integer;
var
  Memory: PChar;
  Index: Integer;
  Val: Integer;
begin
  Result := 0;
  Memory := Data;
  for Index := 0 to 4 do
  begin
    Dec(HaveSize);
    Inc(TotalSize);
    if (HaveSize < 0) or (Index = 4) then
    begin
      Result := -1;
      Exit;
    end;
    Val := Ord(Memory^);
    Inc(Memory);
    Result := (Result shl 7) or (Val and 127);
    if (Val and 128) = 0 then
      Break;
  end;
  Data := Memory;
end;

function VarLenWrite(var Data: Pointer; Value: Integer): Integer;
var
  Temp: array[0..3] of Byte;
  Cnt: Integer;
  Memory: PChar;
begin
  Result := 0;
  if (Value < 0) or (Value > $0fffffff) then
    Exit;
  Cnt := 0;
  while True do
  begin
    Temp[Cnt] := (Value and 127) or 128;
    Value := Value shr 7;
    if Value = 0 then
      Break;
    Inc(Cnt);
  end;
  Result := Cnt + 1;
  Temp[0] := Temp[0] and 127;
  Memory := Data;
  repeat
    Memory^ := Chr(Temp[Cnt]);
    Inc(Memory);
    Dec(Cnt);
  until Cnt < 0;
  Data := Memory;
end;

function ReadBytes(var ReadFrom: Pointer; SaveTo: Pointer; Size: Integer; var HaveSize, TotalSize: Integer): Boolean;
var
  Memory: PChar;
begin
  if HaveSize < Size then
  begin
    Result := True;
    Exit;
  end
  else
    Result := False;
  Memory := ReadFrom;
  Move(Memory^, SaveTo^, Size);
  Inc(Memory, Size);
  ReadFrom := Memory;
  dec(HaveSize, Size);
  Inc(TotalSize, Size);
end;

function WriteBytes(var SaveTo: Pointer; DataFrom: Pointer; Size: Integer): Integer;
var
  Memory: PChar;
begin
  Memory := SaveTo;
  Move(DataFrom^, Memory^, Size);
  Inc(Memory, Size);
  SaveTo := Memory;
  Result := Size;
end;

constructor TMidiTrack.Create();
begin
  Events := TCachedList.Create();
end;

destructor TMidiTrack.Destroy();
begin
  Events.Clear(True);
  Events.Free();
end;

procedure TMidiTrack.Clear();
begin
  Events.Clear(True);
  FreeAndNil(Events);
end;

function TMidiTrack.GetSize(): Integer;
var
  Index: Integer;
  Event: TMidiEvent;
begin
  Result := 8;
  for Index := 0 to Events.Count - 1 do
  begin
    Event := Events[Index] as TMidiEvent;
    Inc(Result, Event.GetSize());
  end;
end;

function TMidiTrack.ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
var
  Track: PRawMidiTrack;
  Size: Integer;
  Event: TMidiEvent;
begin
  try
    Track := LoadFrom;
    Size := LittleInteger(Track.Size);
    Inc(TotalSize, 8);
    Dec(HaveSize, 8 + Size);
    if HaveSize < 0 then
      Abort;
    if Track.Id <> ID_MTrk then
      Abort;
    LoadFrom := @Track.Data;
    while Size > 0 do
    begin
      Event := TMidiEvent.Create();
      if Event.ParseFrom(LoadFrom, Size, TotalSize) then
      begin
        Event.Free();
        Abort;
      end;
      Self.Events.PushRight(Event);
    end;
    Result := False;
  except
    Clear();
    Result := True;
  end;
end;

function TMidiTrack.EncodeTo(var SaveTo: Pointer): Integer;
var
  Header: PRawMidiTrack;
  Index: Integer;
begin
  Header := SaveTo;
  SaveTo := @Header.Data;
  Result := 0;
  for Index := 0 to Self.Events.Count - 1 do
    Inc(Result, (Self.Events[Index] as TMidiEvent).EncodeTo(SaveTo));
  Header.Id := ID_MTrk;
  Header.Size := LittleInteger(Result);
  Inc(Result, 8);
end;

function TMidiTrack.FilterSys(): Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := Events.Count - 1 downto 0 do
    if (Events[Index] as TMidiEvent).IsSystem() then
    begin
      Events.Delete(Index).Free();
      Inc(Result);
    end;
end;

function TMidiTrack.FilterText(): Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := Events.Count - 1 downto 0 do
  begin
    if (Events[Index] as TMidiEvent).IsText() then
    begin
      Events.Delete(Index).Free();
      Inc(Result);
    end;
  end;
end;

function TMidiEvent.IsSystem(): Boolean;
begin
  Result := ((EventType and $f0) = $f0) and (EventType <> 255);
end;

function TMidiEvent.IsMeta(): Boolean;
begin
  Result := (EventType = 255);
end;

function TMidiEvent.IsChannel(): Boolean;
begin
  Result := (EventType and $f0) <> $f0;
end;

function TMidiEvent.TwoParams(): Boolean;
begin
  Result := ((EventType and $f0) <> $c0) and ((EventType and $f0) <> $d0);
end;

function TMidiEvent.IsText(): Boolean;
begin
  Result := (EventType = 255) and (MetaType > 0) and (MetaType < 80);
end;

destructor TMidiEvent.Destroy();
begin
  Clear();
end;

procedure TMidiEvent.Clear();
begin
  if MetaData <> nil then
    FreeMem(MetaData);
  DeltaTime := -1;
  EventType := 255;
  Param1 := 255;
  Param2 := 255;
  MetaType := 255;
  MetaLength := -1;
  MetaData := nil;
end;

function TMidiEvent.GetSize(): Integer;
var
  Data: Integer;
  Temp: Pointer;
begin
  Temp := @Data;
  Result := VarLenWrite(Temp, DeltaTime);
  Temp := @Data;
  if IsChannel() then
  begin
    if TwoParams() then
      Inc(Result, 3)
    else
      Inc(Result, 2);
  end
  else if IsMeta() then
    Inc(Result, 2 + MetaLength + VarLenWrite(Temp, MetaLength))
  else
    Inc(Result, 1 + MetaLength + VarLenWrite(Temp, MetaLength));
end;

function TMidiEvent.ParseFrom(var LoadFrom: Pointer; var HaveSize, TotalSize: Integer): Boolean;
begin
  try
    Self.DeltaTime := VarLenRead(LoadFrom, HaveSize, TotalSize);
    if (Self.DeltaTime < 0) then
      Abort;
    if ReadBytes(LoadFrom, @Self.EventType, 1, HaveSize, TotalSize) then
      Abort;
    if Self.EventType < 128 then
      Abort;
    if Self.IsMeta() then
    begin
      if ReadBytes(LoadFrom, @Self.MetaType, 1, HaveSize, TotalSize) then
        Abort;
      Self.MetaLength := VarLenRead(LoadFrom, HaveSize, TotalSize);
      if Self.MetaLength < 0 then
        Abort;
      if Self.MetaLength > 0 then
      begin
        GetMem(Self.MetaData, Self.MetaLength);
        if ReadBytes(LoadFrom, Self.MetaData, Self.MetaLength, HaveSize, TotalSize) then
          Abort;
      end;
    end
    else if Self.IsSystem() then
    begin
      Self.MetaType := 255;
      Self.MetaLength := VarLenRead(LoadFrom, HaveSize, TotalSize);
      if Self.MetaLength < 0 then
        Abort;
      if Self.MetaLength > 0 then
      begin
        GetMem(Self.MetaData, Self.MetaLength);
        if ReadBytes(LoadFrom, Self.MetaData, Self.MetaLength, HaveSize, TotalSize) then
          Abort;
      end;
    end
    else
    begin
      if ReadBytes(LoadFrom, @Self.Param1, 1, HaveSize, TotalSize) then
        Abort;
      if Self.TwoParams() then
        if ReadBytes(LoadFrom, @Self.Param2, 1, HaveSize, TotalSize) then
          Abort;
    end;
    Result := False;
  except
    Clear();
    Result := True;
  end;
end;

function TMidiEvent.EncodeTo(var SaveTo: Pointer): Integer;
begin
  Result := 0;
  Inc(Result, VarLenWrite(SaveTo, Self.DeltaTime));
  Inc(Result, WriteBytes(SaveTo, @Self.EventType, 1));
  if Self.IsMeta() then
  begin
    Inc(Result, WriteBytes(SaveTo, @Self.MetaType, 1));
    Inc(Result, VarLenWrite(SaveTo, Self.MetaLength));
    if Self.MetaLength > 0 then
      Inc(Result, WriteBytes(SaveTo, Self.MetaData, Self.MetaLength));
  end
  else if Self.IsSystem() then
  begin
    Inc(Result, VarLenWrite(SaveTo, Self.MetaLength));
    if Self.MetaLength > 0 then
      Inc(Result, WriteBytes(SaveTo, Self.MetaData, Self.MetaLength));
  end
  else
  begin
    Inc(Result, WriteBytes(SaveTo, @Self.Param1, 1));
    if Self.TwoParams() then
      Inc(Result, WriteBytes(SaveTo, @Self.Param2, 1));
  end;
end;

procedure TMidiFile.Clear();
begin
  FreeAndNil(Tracks);
end;

function TMidiFile.GetSize(): Integer;
var
  Index: Integer;
  Track: TMidiTrack;
begin
  Result := 14;
  for Index := 0 to Tracks.Count - 1 do
  begin
    Track := Tracks[Index] as TMidiTrack;
    Inc(Result, Track.GetSize());
  end;
end;

function TMidiFile.FilterSys(): Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := 0 to Tracks.Count - 1 do
    Inc(Result, (Tracks[Index] as TMidiTrack).FilterSys());
end;

function TMidiFile.FilterText(): Integer;
var
  Index: Integer;
begin
  Result := 0;
  for Index := 0 to Tracks.Count - 1 do
    Inc(Result, (Tracks[Index] as TMidiTrack).FilterText());
end;

function TMidiFile.Open(FileName: string): Boolean;
var
  Stream: TFileStream;
  Have, Total: Integer;
  Data, Memory: Pointer;
begin
  Clear();
  Total := 0;
  Stream := nil;
  Memory := nil;
  try
    Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    Have := Stream.Size;
    GetMem(Memory, Have);
    stream.ReadBuffer(Memory^, Have);
    Result := True;
  except
    Result := False;
  end;
  stream.Free();
  Data := Memory;
  if Result then
    Result := Open(Data, Have, Total);
  if Memory <> nil then
    FreeMem(Memory);
end;

function TMidiFile.Open(var RawMidi: Pointer; var HaveSize, TotalSize: Integer): Boolean;
var
  RawHeader: PRawMidiHeader;
  Memory: PChar;
  Index, Count: Integer;
  Track: TMidiTrack;
begin
  Memory := RawMidi;
  Tracks := TCachedList.Create();
  try
    RawHeader := Pointer(Memory);
    if HaveSize < 22 then
      Abort;
    if RawHeader.Id <> ID_MThd then
      Abort;
    FormatType := LittleWord(RawHeader.Format);
    if (Integer(RawHeader.Format) < 0) and (RawHeader.Format > 2) then
      Abort;
    Count := LittleWord(RawHeader.Tracks);
    TimeDivision := LittleWord(RawHeader.Time);
    Index := LittleInteger(RawHeader.Size) + 8;
    Inc(Memory, Index);
    Inc(TotalSize, Index);
    Dec(HaveSize, Index);
    RawMidi := Memory;
    if HaveSize < 0 then
      Abort;
    for Index := 0 to Count - 1 do
    begin
      Track := TMidiTrack.Create();
      Track.ParseFrom(RawMidi, HaveSize, TotalSize);
      if Track = nil then
      begin
        Track.Free();
        Abort;
      end;
      Tracks.PushRight(Track);
    end;
    Result := True;
  except
    Result := False;
  end;
  if not Result then
    Clear();
end;

function TMidiFile.Save(var SaveTo: Pointer): Integer;
var
  Header: PRawMidiHeader;
  Index: Integer;
begin
  Header := SaveTo;
  SaveTo := @Header.Data;
  Result := 0;
  for Index := 0 to Tracks.Count - 1 do
    Inc(Result, (Tracks[Index] as TMidiTrack).EncodeTo(SaveTo));
  Header.Id := ID_MThd;
  Header.Size := LittleInteger(6);
  Header.Format := LittleWord(FormatType);
  Header.Tracks := LittleWord(Tracks.Count);
  Header.Time := LittleWord(TimeDivision);
  Inc(Result, 14);
end;

function TMidiFile.Save(FileName: string): Integer;
var
  Stream: TFileStream;
  Data, Memory: Pointer;
begin
  Stream := nil;
  Memory := nil;
  try
    Result := GetSize();
    if Result <= 0 then
      Abort;
    GetMem(Memory, Result);
    Data := Memory;
    Result := Save(Data);
    if Result <= 0 then
      Abort;
    Stream := TFileStream.Create(FileName, fmCreate);
    Stream.WriteBuffer(Memory^, Result);
  except
    Result := -1;
  end;
  stream.Free();
  if Memory <> nil then
    FreeMem(Memory);
end;

end.

